import 'dart:io' as io;

import 'package:configr/src/di.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/hooks/hook_manager.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/multi_host/inventory.dart' show Inventory;
import 'package:configr/src/secrets/sensitive_variable_middleware.dart'
    show SensitiveVariableMiddleware;
import 'package:configr/src/utils/command_executor.dart';
import 'package:configr/src/utils/command_runner.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/utils/logging.dart' show logger;
import 'package:configr/src/utils/network_service.dart';
import 'package:configr/src/utils/privilege_escalation.dart'
    show NoPrivilegeEscalation, PrivilegeEscalation;
import 'package:configr/src/utils/ssh_execution_service.dart'
    show SSHExecutionService;
import 'package:file/file.dart' show FileSystem;
import 'package:i3config/i3config_v2.dart' as i3;

/// Base class for configr action blocks — the v2 replacement for the old
/// handler → data-model → execution-module triad.
///
/// An [ActionBlock] is both an i3config v2 [i3.BlockHandler] **and** a
/// self-executing action:
///
/// 1. **Parse** — the i3config v2 state machine dispatches blocks to
///    [handle] / [afterChildrenProcessed]. Properties written as
///    `source = "/tmp/foo"` (assignment syntax) are handled automatically
///    by the processor's built-in assignment handler.
/// 2. **Execute** — [afterChildrenProcessed] calls [readAdditionalProperties]
///    for subclass-specific properties, then calls [execute] immediately
///    (unless [dryRun] is true).
///
/// Because the i3 processor uses a **single handler instance** per block type,
/// per-block state is captured from the block-specific [i3.Context] and used
/// immediately. There is no collector pattern — each block executes as it is
/// processed.
///
/// Subclass contract:
/// - Override [blockType] to declare the i3 config keyword (e.g. `'copy'`).
/// - Override [registerScopedCommands] for **command-style** properties
///   (e.g. `include "*.dart"`, NOT `include = "*.dart"`).
/// - Override [readAdditionalProperties] to read type-specific context
///   variables into typed fields (instead of overriding
///   [afterChildrenProcessed] directly).
/// - Implement [execute] and [rollback].
abstract class ActionBlock extends i3.BaseBlockHandler {
  // ---------------------------------------------------------------------------
  // ResourceModel-like fields — populated from context variables
  // ---------------------------------------------------------------------------

  String id = '';
  String source = '';
  String destination = '';
  String? type;
  String? status;
  String? delegateTo;
  String? sha256;
  String? renderedContent;
  bool sourceWasExplicitlySet = false;
  Map<String, dynamic> properties = const {};
  List<ActionBlock> children = [];

  // ---------------------------------------------------------------------------
  // Dependencies — resolved from the DI container
  // ---------------------------------------------------------------------------

  EventBus get eventBus => di<EventBus>();
  PrivilegeEscalation get privilegeEscalation => di<PrivilegeEscalation>();
  FileSystem get fileSystem => di<FileSystem>();
  FileService get fileService => di<FileService>();
  CommandRunner get commandRunner => di<CommandRunner>();
  NetworkService get networkService => di<NetworkService>();

  /// When true, [execute] is skipped during processing.
  /// Used by tests that only want to verify property parsing.
  bool get dryRun => di<DryRunFlag>().value;

  /// Context for the current block being processed.
  /// Available during [execute] after [afterChildrenProcessed] is called.
  i3.Context get context => _context!;

  ActionBlock();

  // ---------------------------------------------------------------------------
  // i3config v2 handler lifecycle
  // ---------------------------------------------------------------------------

  @override
  void handle(i3.Block block, i3.Context context) {
    // Nothing to do here — properties are read in afterChildrenProcessed.
  }

  /// Register block-scoped command handlers for **non-assignment** properties.
  ///
  /// Properties using `=` syntax (e.g. `source = "/tmp/foo"`) are handled
  /// by the processor's built-in [i3.AssignmentProcessingState] — they are
  /// automatically stored as context variables.
  ///
  /// Override this only for properties that use **command syntax**
  /// (e.g. `include "*.dart"` without `=`).
  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    // Subclasses add command-style property handlers here.
  }

  /// Called by the i3 processor after all children of a block have been
  /// processed. **Do not override** in subclasses — override
  /// [readAdditionalProperties] instead.
  ///
  /// This method:
  /// 1. Resets per-instance state (the same handler is reused for every block
  ///    of the same type, so fields must be cleared before reading).
  /// 2. Reads common properties (id, source, destination, etc.) from context.
  /// 3. Auto-generates a UUID [id] if none was set, so every block has a
  ///    globally unique identifier for lockfile tracking and rollback.
  /// 4. Calls [readAdditionalProperties] so subclasses can read type-specific
  ///    properties.
  /// 5. Calls [execute] unless [dryRun] is true.
  ///
  /// Each block's [execute] method is responsible for emitting its own
  /// [StartedEvent] and [CompletedEvent] with operation-specific details.
  /// The base class only emits a generic [FailedEvent] as a fallback when
  /// execute() throws — this ensures every failure is observable even if a
  /// block doesn't catch an error internally.
  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    // ----- 0. Reset per-instance state -----
    // The same ActionBlock instance is reused for every block of the same
    // type in the config.  Without a reset, fields from the previous block
    // (especially `id`) persist and corrupt the next one.
    resetState();

    // ----- 1. Read common properties -----
    id = context.getString('id');
    source = context.getString('source');
    sourceWasExplicitlySet = source.isNotEmpty;
    destination = context.getString('destination');
    // Backward compat: if source is empty, fall back to destination.
    // Many v1 configs set 'destination' at the resource level but action
    // blocks read 'source' for the file path (e.g. touch, delete, rename).
    if (source.isEmpty && destination.isNotEmpty) {
      source = destination;
    }
    status = context.getVariableAs<String>('status');
    sha256 = context.getVariableAs<String>('sha256');
    renderedContent = context.getVariableAs<String>('_rendered_content');
    children = [];

    final rawProps = <String, dynamic>{
      ?context.getVariableAs<String>('type'): 'type',
    };
    if (rawProps.isNotEmpty) properties = rawProps;

    // ----- 2. Auto-generate friendly name for unnamed blocks -----
    // Each block gets a human-readable name like `download_0`, `copy_1`
    // so event output shows block type names instead of UUIDs. The counter
    // is tracked in the processor context so it resets across processing runs.
    if (id.isEmpty) {
      final counters =
          context.globalContext.options['_blockCounters']
              as Map<String, int>? ??
          <String, int>{};
      context.globalContext.options['_blockCounters'] = counters;
      final count = (counters[blockType] ?? 0) + 1;
      counters[blockType] = count;
      id = '${blockType}_${count - 1}';
    }

    // ----- 3. Let subclasses read their properties -----
    await readAdditionalProperties(block, context);

    // ----- 4. Register with collectors so consumers can inspect parsed
    // properties. Not used by the production pipeline (execution happens
    // in step 5), but critical for tests and CLI commands.
    //
    // We maintain two parallel collectors:
    //   _actionBlocks  – mutable references (used by tests, v2 helper)
    //   _blockSnapshots – immutable snapshots (used by diff/status/watch)
    //
    // The snapshot is taken at registration time so it captures this
    // block's state before the singleton is reused for the next block.
    final mutableCollector =
        context.globalContext.options['_actionBlocks'] as List<ActionBlock>?;
    mutableCollector?.add(this);

    final snapshotCollector =
        context.globalContext.options['_blockSnapshots']
            as List<BlockSnapshot>?;
    if (snapshotCollector != null) {
      snapshotCollector.add(BlockSnapshot.fromActionBlock(this));
    }

    // ----- 5. Check fail-fast before executing -----
    // If failFast is enabled and a previous block already failed, skip
    // execution of this block. The error(s) will cause the apply to fail.
    final failFast = context.globalContext.options['_failFast'] == true;
    final hasPriorErrors =
        (context.globalContext.options['_errors'] as List<BlockErrorRecord>?)
            ?.isNotEmpty ??
        false;
    if (failFast && hasPriorErrors) {
      emitEvent(
        StatusUpdateEvent(
          moduleId: id,
          level: StatusEvent.warning,
          message:
              'Skipping $blockType block (fail-fast mode — previous block failed)',
        ),
      );
    } else if (dryRun) {
      // ----- 6. Dry-run: print what would happen -----
      final summary = dryRunSummary();
      if (summary.isNotEmpty) {
        final sensitiveMw =
            context.globalContext.options['_sensitiveMiddleware']
                as SensitiveVariableMiddleware?;
        final safe = sensitiveMw != null && sensitiveMw.hasSensitiveKeys
            ? sensitiveMw.redact(summary)
            : summary;
        print('  [DRY-RUN] $safe');
      }
    } else {
      // ----- 7. Execute (unless dry-run) -----
      _context = context;

      // Run pre-block hook if a HookManager is registered
      final hookMgr =
          context.globalContext.options['_hookManager'] as HookManager?;
      if (hookMgr != null) {
        await hookMgr.runEvent(
          'pre-block',
          extraVars: {
            'block_type': blockType,
            'block_id': id,
            'block_source': source,
            'block_destination': destination,
          },
        );
      }

      // ----- 7a. Connect delegate SSH if delegate_to is set -----
      if (delegateTo != null) {
        try {
          _delegateService = await _connectToDelegate(delegateTo!, context);
        } catch (e) {
          emitEvent(
            FailedEvent(
              moduleId: id,
              message: 'Failed to connect to delegate host "$delegateTo": $e',
            ),
          );
          final errors =
              (context.globalContext.options['_errors']
                  as List<BlockErrorRecord>?) ??
              <BlockErrorRecord>[];
          context.globalContext.options['_errors'] = errors;
          errors.add(
            BlockErrorRecord(
              message:
                  'Failed $blockType block: could not connect to delegate host "$delegateTo": $e',
              blockType: blockType,
              blockId: id,
              source: block.span != null ? _formatSpan(block.span!) : null,
            ),
          );
          return;
        }
      }

      try {
        await execute();

        // Run post-block hook after successful execution
        if (hookMgr != null) {
          await hookMgr.runEvent(
            'post-block',
            extraVars: {
              'block_type': blockType,
              'block_id': id,
              'block_source': source,
              'block_destination': destination,
            },
          );
        }

        // Record this block in the lockfile collector (if present).
        await _recordApplied(context);
      } catch (e) {
        emitEvent(
          FailedEvent(moduleId: id, message: 'Failed $blockType block: $e'),
        );
        // Attempt rollback
        try {
          await rollback();
        } catch (rbErr) {
          // Silently swallow rollback errors — the original error is the
          // important one.
        }
        // Collect errors in processor context instead of rethrowing.
        // The i3 processor catches all exceptions and continues, so
        // rethrow doesn't propagate. By collecting errors here, we can
        // check for failures after processor.process() completes and
        // only write the lockfile / report success if no errors occurred.
        // Create a BlockErrorRecord with source span info for diagnostics.
        final errors =
            (context.globalContext.options['_errors']
                as List<BlockErrorRecord>?) ??
            <BlockErrorRecord>[];
        context.globalContext.options['_errors'] = errors;
        errors.add(
          BlockErrorRecord(
            message: 'Failed $blockType block: $e',
            blockType: blockType,
            blockId: id,
            source: block.span != null ? _formatSpan(block.span!) : null,
          ),
        );
      } finally {
        await _disconnectDelegate();
      }
    }
  }

  /// Reset subclass-specific state before processing a new block instance.
  ///
  /// The same handler instance is reused for every block of the same type
  /// in the config. Override this to reset any execution state fields that
  /// should not carry over (e.g., counters, temporary paths, etc.).
  ///
  /// ```dart
  /// @override
  /// void resetState() {
  ///   super.resetState();
  ///   overwrite = false;
  ///   resumeEnabled = false;
  ///   receivedBytes = 0;
  /// }
  /// ```
  void resetState() {
    id = '';
    source = '';
    destination = '';
    type = null;
    status = null;
    delegateTo = null;
    _delegateService = null;
    sha256 = null;
    renderedContent = null;
    sourceWasExplicitlySet = false;
    properties = const {};
    children = [];
    _context = null;
  }

  /// Override this to read type-specific properties from the context.
  ///
  /// Called by [afterChildrenProcessed] after common properties have been
  /// read and before [execute] is called.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Future<void> readAdditionalProperties(
  ///   i3.Block block,
  ///   i3.Context context,
  /// ) async {
  ///   message = (context.getVariable('message') as String?) ?? message;
  /// }
  /// ```
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    delegateTo = context.getVariableAs<String>('delegate_to');
  }

  /// Context for the current block being processed.
  /// Set during [afterChildrenProcessed] before calling [execute].
  i3.Context? _context;

  /// Override this to provide a description of what this block would do
  /// during a dry-run. Called when `--dry-run` is active and `execute()`
  /// is skipped. Return an empty string to suppress output.
  ///
  /// The default shows the block type, id, source, and destination.
  String dryRunSummary() {
    final parts = <String>[];
    if (id.isNotEmpty) parts.add('id=$id');
    if (source.isNotEmpty) parts.add('source=$source');
    if (destination.isNotEmpty) parts.add('destination=$destination');
    if (delegateTo != null) parts.add('delegate_to=$delegateTo');
    if (parts.isEmpty) return '';
    return '$blockType: ${parts.join(', ')}';
  }

  /// Override this to provide additional properties for serialization.
  ///
  /// Called by [I3ConfigWriterV2] when writing this block back to i3 text.
  /// Return a map of property name → value pairs that should be emitted
  /// as `Assignment` nodes inside the block.
  ///
  /// Common properties (`id`, `source`, `destination`, `type`, `sha256`,
  /// `status`) are already handled by the writer — do NOT include them here.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, String> get additionalProperties => {
  ///   'message': message,
  ///   'level': level,
  /// };
  /// ```
  Map<String, String> get additionalProperties => const {};

  /// Override this to provide boolean properties for serialization.
  ///
  /// Boolean properties that were set to `true` are emitted as
  /// `prop = true`; `false` values are omitted (they are defaults).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, bool> get additionalBoolProperties => {
  ///   'recursive': recursive,
  /// };
  /// ```
  Map<String, bool> get additionalBoolProperties => const {};

  // ---------------------------------------------------------------------------
  // Execution interface
  // ---------------------------------------------------------------------------

  /// Execute this action block.
  Future<void> execute();

  /// Rollback this action block (undo whatever [execute] did).
  Future<void> rollback();

  // ---------------------------------------------------------------------------
  // Event helpers
  // ---------------------------------------------------------------------------

  /// Override to attach block-specific metadata to the lockfile record
  /// (e.g. installed package versions).
  Map<String, dynamic>? get lockfileMetadata {
    if (delegateTo != null) {
      return {'delegate_to': delegateTo};
    }
    return null;
  }

  /// Record this block in the lockfile collector if one is active.
  ///
  /// If [sha256] was not explicitly set by the block but [destination] points
  /// to a file, the checksum is computed automatically for drift detection.
  Future<void> _recordApplied(i3.Context context) async {
    final collector =
        context.globalContext.options['_appliedBlocks']
            as List<AppliedBlockRecord>?;
    if (collector == null) return;

    var autoSha256 = sha256;
    if (autoSha256 == null || autoSha256.isEmpty) {
      if (destination.isNotEmpty) {
        try {
          if (await fileService.fileExists(destination)) {
            autoSha256 = await fileService.computeFileHash(destination);
          }
        } catch (_) {
          // Non-critical — drift detection just won't have a baseline.
        }
      }
    }

    collector.add(
      AppliedBlockRecord(
        blockType: blockType,
        id: id,
        source: source,
        destination: destination,
        appliedAt: DateTime.now().toUtc().toIso8601String(),
        status: 'completed',
        sha256: autoSha256,
        metadata: lockfileMetadata,
      ),
    );
  }

  /// Restore block state from a lockfile record after [resetState].
  ///
  /// Subclasses override to restore block-specific properties needed for
  /// rollback.
  void restoreFromRecord(AppliedBlockRecord record) {
    id = record.id;
    source = record.source;
    destination = record.destination;
    sha256 = record.sha256;
    status = record.status;
    delegateTo = record.metadata?['delegate_to'] as String?;
  }

  void emitEvent(ModuleEvent event) {
    final redacted = _redactEvent(event);
    eventBus.emit(redacted);
  }

  ModuleEvent _redactEvent(ModuleEvent event) {
    final ctx = _context;
    if (ctx == null) return event;
    final sensitiveMw =
        ctx.globalContext.options['_sensitiveMiddleware']
            as SensitiveVariableMiddleware?;
    if (sensitiveMw == null || !sensitiveMw.hasSensitiveKeys) return event;
    final message = _getEventMessage(event);
    if (message == null || message.isEmpty) return event;
    final redactedMessage = sensitiveMw.redact(message);
    if (redactedMessage == message) return event;
    return _withRedactedMessage(event, redactedMessage);
  }

  String? _getEventMessage(ModuleEvent event) {
    return switch (event) {
      StartedEvent e => e.message,
      ProgressEvent e => e.message,
      CompletedEvent e => e.message,
      FailedEvent e => e.message,
      StatusUpdateEvent e => e.message,
      ErrorEvent e => e.message,
      DownloadProgressEvent e => e.message,
      _ => null,
    };
  }

  ModuleEvent _withRedactedMessage(ModuleEvent event, String message) {
    return switch (event) {
      StartedEvent e => StartedEvent(
        moduleId: e.moduleId,
        message: message,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      ProgressEvent e => ProgressEvent(
        moduleId: e.moduleId,
        message: message,
        current: e.current,
        total: e.total,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      CompletedEvent e => CompletedEvent(
        moduleId: e.moduleId,
        message: message,
        duration: e.duration,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      FailedEvent e => FailedEvent(
        moduleId: e.moduleId,
        message: message,
        errorCode: e.errorCode,
        cause: e.cause,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      StatusUpdateEvent e => StatusUpdateEvent(
        moduleId: e.moduleId,
        message: message,
        level: e.level,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      ErrorEvent e => ErrorEvent(
        moduleId: e.moduleId,
        message: message,
        errorCode: e.errorCode,
        severity: e.severity,
        category: e.category,
        isRetryable: e.isRetryable,
        retryAfter: e.retryAfter,
        cause: e.cause,
        correlationId: e.correlationId,
        timestamp: e.timestamp,
        metadata: e.metadata,
      ),
      _ => event,
    };
  }

  // ---------------------------------------------------------------------------
  // Privilege-aware command execution
  // ---------------------------------------------------------------------------

  /// Runs [command] with [args], optionally elevating via [privilegeEscalation]
  /// when [requireElevation] is true.
  ///
  /// Returns the [io.ProcessResult] from the execution.
  /// Throws if the process exits with a non-zero code.
  SSHExecutionService? _delegateService;

  ExecutionService get executionService {
    if (_delegateService != null) return _delegateService!;
    return di.isRegistered<ExecutionService>()
        ? di<ExecutionService>()
        : const LocalExecutionService();
  }

  /// Best-effort target platform name for OS-specific behavior.
  ///
  /// Prefer the config context because remote applies seed this from
  /// [TargetSystemProbe]. Fall back to the execution service when the block is
  /// used outside the normal apply pipeline.
  String get targetPlatform {
    final globalPlatform = _context?.globalContext.options['_targetPlatform'];
    if (globalPlatform is String && globalPlatform.isNotEmpty) {
      return globalPlatform;
    }
    final osName = _context?.getVariable('os_name')?.toString();
    if (osName != null && osName.isNotEmpty) return osName;
    return executionService.platform;
  }

  /// Connect to a delegate host via SSH.
  ///
  /// Looks up [hostName] in the inventory (stored in global context options).
  /// Falls back to a raw connection with default SSH config if not found.
  Future<SSHExecutionService> _connectToDelegate(
    String hostName,
    i3.Context context,
  ) async {
    final inventory = context.globalContext.options['_inventory'];
    final ssh = SSHExecutionService();
    if (inventory is Inventory) {
      final host = inventory.getHost(hostName);
      if (host != null) {
        await ssh.connect(host.toConnectionMap());
        return ssh;
      }
      logger.warning(
        'Host "$hostName" not found in inventory — '
        'connecting with default SSH config',
      );
    }
    await ssh.connect(<String, dynamic>{'host': hostName});
    return ssh;
  }

  Future<void> _disconnectDelegate() async {
    final service = _delegateService;
    _delegateService = null;
    if (service != null) {
      try {
        await service.disconnect();
      } catch (_) {
        // Non-critical — delegate connection cleanup errors are safe to ignore.
      }
    }
  }

  Future<io.ProcessResult> runCommand(
    String command,
    List<String> args, {
    bool requireElevation = false,
    String? workingDirectory,
    bool checkExitCode = true,
  }) async {
    if (requireElevation) {
      final result = await privilegeEscalation.runWithElevatedPrivileges(
        command,
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      if (checkExitCode && result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        throw Exception('Command failed: $err');
      }
      return result;
    }

    final cmd = Command(name: command, command: command, parameters: args);
    return CommandExecutor.execute(
      cmd,
      NoPrivilegeEscalation(),
      workingDirectory: workingDirectory,
      runInShell: true,
      checkExitCode: checkExitCode,
      executionService: executionService,
    );
  }
}

/// Immutable snapshot of an ActionBlock's parsed properties.
///
/// Used by the collector in afterChildrenProcessed to capture per-block
/// state without holding a reference to the mutable singleton ActionBlock
/// instance (which gets reused for every block of the same type).
class BlockSnapshot {
  final String blockType;
  final String id;
  final String source;
  final String destination;
  final String? status;
  final String? sha256;
  final Map<String, dynamic> properties;

  const BlockSnapshot({
    required this.blockType,
    required this.id,
    required this.source,
    required this.destination,
    this.status,
    this.sha256,
    this.properties = const {},
  });

  factory BlockSnapshot.fromActionBlock(ActionBlock block) {
    return BlockSnapshot(
      blockType: block.blockType,
      id: block.id,
      source: block.source,
      destination: block.destination,
      status: block.status,
      sha256: block.sha256,
      properties: block.properties,
    );
  }
}

/// Records a block execution error with its source location for diagnostics.
class BlockErrorRecord {
  final String message;
  final String blockType;
  final String blockId;
  final String? source;

  const BlockErrorRecord({
    required this.message,
    required this.blockType,
    required this.blockId,
    this.source,
  });

  @override
  String toString() {
    if (source != null) {
      return '$message ($source)';
    }
    return message;
  }
}

/// Formats a source span (from i3config's SourceSpan) into a human-readable
/// `line:col` string.
String _formatSpan(dynamic span) {
  if (span == null) return '';
  // source_span's SourceSpan has start.line and start.column (0-based).
  final start = span.start;
  return 'line ${start.line + 1}, column ${start.column + 1}';
}
