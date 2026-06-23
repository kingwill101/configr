import 'dart:io' as io;

import 'package:configr/src/di.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/command_executor.dart';
import 'package:configr/src/utils/event_bus.dart';

import 'package:configr/src/utils/privilege_escalation.dart'
    show NoPrivilegeEscalation, PrivilegeEscalation;
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

  /// When true, [execute] is skipped during processing.
  /// Used by tests that only want to verify property parsing.
  bool get dryRun => di<DryRunFlag>().value;

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
    id = (context.getVariable('id') as String?) ?? '';
    source = (context.getVariable('source') as String?) ?? '';
    sourceWasExplicitlySet = source.isNotEmpty;
    destination = (context.getVariable('destination') as String?) ?? '';
    // Backward compat: if source is empty, fall back to destination.
    // Many v1 configs set 'destination' at the resource level but action
    // blocks read 'source' for the file path (e.g. touch, delete, rename).
    if (source.isEmpty && destination.isNotEmpty) {
      source = destination;
    }
    status = context.getVariable('status') as String?;
    sha256 = context.getVariable('sha256') as String?;
    renderedContent = context.getVariable('_rendered_content') as String?;
    children = [];

    final rawProps = <String, dynamic>{?context.getVariable('type'): 'type'};
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
        print('  [DRY-RUN] $summary');
      }
    } else {
      // ----- 7. Execute (unless dry-run) -----
      try {
        await execute();
        // Record this block in the lockfile collector (if present).
        _recordApplied(context);
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
    sha256 = null;
    renderedContent = null;
    sourceWasExplicitlySet = false;
    properties = const {};
    children = [];
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
    // Subclasses override this.
  }

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

  /// Record this block in the lockfile collector if one is active.
  void _recordApplied(i3.Context context) {
    final collector =
        context.globalContext.options['_appliedBlocks']
            as List<AppliedBlockRecord>?;
    if (collector != null) {
      collector.add(
        AppliedBlockRecord(
          blockType: blockType,
          id: id,
          source: source,
          destination: destination,
          appliedAt: DateTime.now().toUtc().toIso8601String(),
          status: 'completed',
          sha256: sha256,
        ),
      );
    }
  }

  void emitEvent(ModuleEvent event) {
    eventBus.emit(event);
  }

  // ---------------------------------------------------------------------------
  // Privilege-aware command execution
  // ---------------------------------------------------------------------------

  /// Runs [command] with [args], optionally elevating via [privilegeEscalation]
  /// when [requireElevation] is true.
  ///
  /// Returns the [io.ProcessResult] from the execution.
  /// Throws if the process exits with a non-zero code.
  Future<io.ProcessResult> runCommand(
    String command,
    List<String> args, {
    bool requireElevation = false,
    String? workingDirectory,
    bool checkExitCode = true,
  }) async {
    final cmd = Command(
      name: command,
      command: command,
      parameters: args,
    );
    final escalation = requireElevation
        ? privilegeEscalation
        : NoPrivilegeEscalation();
    return CommandExecutor.execute(
      cmd,
      escalation,
      workingDirectory: workingDirectory,
      runInShell: true,
      checkExitCode: checkExitCode,
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
