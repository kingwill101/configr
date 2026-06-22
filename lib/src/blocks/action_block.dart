import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/event_bus.dart';
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
  Map<String, dynamic> properties = const {};
  List<ActionBlock> children = [];

  // ---------------------------------------------------------------------------
  // Injected dependencies
  // ---------------------------------------------------------------------------

  FileSystem? fileSystem;
  final EventBus? eventBus;

  /// When true, [execute] is skipped during processing.
  /// Used by tests that only want to verify property parsing.
  bool dryRun = false;

  ActionBlock({this.fileSystem, this.eventBus});

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
    destination = (context.getVariable('destination') as String?) ?? '';
    // Backward compat: if source is empty, fall back to destination.
    // Many v1 configs set 'destination' at the resource level but action
    // blocks read 'source' for the file path (e.g. touch, delete, rename).
    if (source.isEmpty && destination.isNotEmpty) {
      source = destination;
    }
    status = context.getVariable('status') as String?;
    sha256 = context.getVariable('sha256') as String?;
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

    // ----- 4. Register with the collector so tests can inspect parsed
    // properties. Not used by the production pipeline (execution happens
    // in step 5), but critical for test assertions.
    final collector =
        context.globalContext.options['_actionBlocks'] as List<ActionBlock>?;
    collector?.add(this);

    // ----- 5. Execute (unless dry-run) -----
    // Blocks emit their own StartedEvent and CompletedEvent with detailed
    // messages. The base class only emits a generic FailedEvent as a fallback
    // when execute() throws and the block didn't emit one (e.g. for source
    // checks that happen before a block's inner try-catch).
    if (!dryRun) {
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
        final errors =
            (context.globalContext.options['_errors'] as List<Object>?) ??
            <Object>[];
        context.globalContext.options['_errors'] = errors;
        errors.add(e);
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
    eventBus?.emit(event);
  }
}
