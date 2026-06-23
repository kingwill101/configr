import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/template.dart';
import 'package:configr/src/reader/config_builder.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:i3config/i3config_v2.dart' as i3;

// ---------------------------------------------------------------------------
// Top-level: create a processor with all Configr handlers registered
// ---------------------------------------------------------------------------

/// Creates a [i3.ConfigProcessor] pre-configured with all Configr block
/// and command handlers.
///
/// The [ConfigBuilder] is stored in the processor's context options under
/// `'configBuilder'` and is populated as the processor walks the AST.
i3.ConfigProcessor createConfigrProcessor(ConfigBuilder builder) {
  final processor = i3.ConfigProcessor();

  // Store the ConfigBuilder in the processor's root context
  processor.context.options['configBuilder'] = builder;

  // -----------------------------------------------------------------------
  // Register ALL block handlers globally.
  //
  // Registering via [registerBlockHandler] also triggers each handler's
  // [registerScopedCommands] which sets up the per-block-type command and
  // sub-block registrations (e.g. action types under `actions`).
  //
  // The state machine resolves handlers in this order:
  //   1. block-scoped block handler (registered by parent handler)
  //   2. global block handler (registered here)
  //
  // So scoped registrations always take priority — global registration
  // is purely a mechanism to get registerScopedCommands called.
  // -----------------------------------------------------------------------

  // ---- top-level section handlers ----
  processor.registerBlockHandler(ResourcesBlockHandler());
  processor.registerBlockHandler(CommandsBlockHandler());
  processor.registerBlockHandler(PackagesBlockHandler());
  processor.registerBlockHandler(ScriptsBlockHandler('pre_apply_scripts'));
  processor.registerBlockHandler(ScriptsBlockHandler('post_apply_scripts'));

  // ---- resource entry handlers ----
  // Register via registerBlockHandler so registerScopedCommands fires.
  // The scoped registration under 'resources' (from ResourcesBlockHandler)
  // still takes priority when inside a resources block.
  processor.registerBlockHandler(ResourceBlockHandler());
  processor.registerBlockHandler(InlineResourceTypeHandler('file'));
  processor.registerBlockHandler(InlineResourceTypeHandler('directory'));

  // ---- actions handler (registers all action types as scoped) ----
  // Build a map of action type → inline collector handlers for the v1
  // pipeline. Each handler creates an old [Action] model object from
  // assignments inside the action block.
  processor.registerBlockHandler(
    ActionsBlockHandler(customActionHandlers: _v1ActionCollectorHandlers()),
  );

  // ---- template & subcommands handlers ----
  processor.registerBlockHandler(TemplateBlockHandler());
  processor.registerBlockHandler(TemplateVarsBlockHandler());
  processor.registerBlockHandler(SubCommandsBlockHandler());

  // ---- command & package entry handlers ----
  processor.registerBlockHandler(CommandEntryBlockHandler());
  processor.registerBlockHandler(PackageEntryBlockHandler());

  return processor;
}

/// Builds a map of action type → inline collector [i3.BlockHandler] for the
/// v1 pipeline. Each handler builds an old [Action] model object from the
/// assignments inside the action block and attaches it to the nearest
/// resource builder in the context chain.
///
/// This replaces the removed [ActionBlockHandler] class and hardcoded
/// [_allActionTypes] list. The v2 pipeline does NOT use these — it passes
/// real [ActionBlock] subclasses as handlers instead.
Map<String, i3.BlockHandler> _v1ActionCollectorHandlers() {
  final types = [
    'backup',
    'copy',
    'delete',
    'executable',
    'permissions',
    'symlink',
    'compress',
    'decompress',
    'download',
    'execute',
    'echo',
    'git',
    'move',
    'rename',
    'network',
    'sync',
    'touch',
    'validate',
    'template',
  ];
  return {for (final type in types) type: _V1ActionCollectorHandler(type)};
}

/// An inline collector handler for the v1 pipeline that builds old [Action]
/// model objects from config blocks.
class _V1ActionCollectorHandler extends i3.BaseBlockHandler {
  @override
  final String blockType;

  _V1ActionCollectorHandler(this.blockType);

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['actionBuilder'] = ActionBuilder(type: blockType);
  }

  @override
  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    // Command properties are auto-set by the i3config v2 processor default.
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final builder = context.options['actionBuilder'] as ActionBuilder?;
    if (builder == null) return;

    builder.id = (context.getVariable('id') as String?) ?? builder.id;
    builder.status = context.getVariable('status') as String?;
    builder.timestamp = context.getVariable('timestamp') as String?;
    builder.sha256 = context.getVariable('sha256') as String?;

    // Collect extra properties from assignments that are not reserved.
    const reserved = {'id', 'status', 'timestamp', 'sha256'};
    for (final element in block.body) {
      if (element is i3.Assignment) {
        final key = element.variable;
        if (!reserved.contains(key)) {
          builder.properties[key] = element.values
              .map((v) => expandValue(v, context))
              .join(' ');
        }
      }
    }

    final action = builder.build();

    // Walk up the context chain to attach to the nearest resource builder.
    var parentCtx = context.parentContext;
    while (parentCtx != null) {
      if (parentCtx.options['resourceBuilder'] is ResourceBuilder) {
        (parentCtx.options['resourceBuilder'] as ResourceBuilder).actions.add(
          action,
        );
        break;
      }
      parentCtx = parentCtx.parentContext;
    }
  }
}

// ===========================================================================
// Property Command Handlers (kept for special cases)
// ===========================================================================

class _ParametersHandler extends i3.BaseCommandHandler<List<String>> {
  @override
  String get commandName => 'parameters';
  @override
  List<String>? handle(i3.Command command, i3.Context context) {
    final values = getAllArgsAsStrings(command, context);
    context.setVariable(commandName, values);
    return values;
  }
}

class _TemplateStrHandler extends i3.BaseCommandHandler<String> {
  @override
  String get commandName => 'template';
  @override
  String? handle(i3.Command command, i3.Context context) {
    final value = getArgAsString(command, 0, context);
    context.setVariable('template_str', value);
    return value;
  }
}

// ===========================================================================
// ResourcesBlockHandler
// ===========================================================================

/// Handles the top-level `resources { ... }` block.
///
/// Registers `resource`, `file`, and `directory` as scoped block handlers
/// valid only inside `resources`. The state machine automatically routes
/// `resource { ... }`, `file { ... }`, and `directory { ... }` entries
/// to their respective handlers.
///
/// The v2 pipeline passes custom handlers (with [ActionsBlockHandler] wired
/// to ActionBlock subclasses) so that nested resources use real execution
/// blocks instead of v1-style collector handlers.
class ResourcesBlockHandler extends i3.BaseBlockHandler {
  /// Optional custom [ResourceBlockHandler] to register instead of the default.
  /// When set, the v2 pipeline passes a handler wired to ActionBlock subclasses.
  final ResourceBlockHandler? customResourceHandler;

  /// Optional custom [InlineResourceTypeHandler] for `file` blocks.
  final InlineResourceTypeHandler? customFileHandler;

  /// Optional custom [InlineResourceTypeHandler] for `directory` blocks.
  final InlineResourceTypeHandler? customDirectoryHandler;

  ResourcesBlockHandler({
    this.customResourceHandler,
    this.customFileHandler,
    this.customDirectoryHandler,
  });

  @override
  String get blockType => 'resources';

  @override
  void handle(i3.Block block, i3.Context context) {
    // Entry hook — child handlers build resources via the ConfigBuilder.
    // Nothing to do here because the builder is in the global context.
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerScopedBlockHandler(
      'resource',
      customResourceHandler ?? ResourceBlockHandler(),
    );
    registry.registerScopedBlockHandler(
      'file',
      customFileHandler ?? InlineResourceTypeHandler('file'),
    );
    registry.registerScopedBlockHandler(
      'directory',
      customDirectoryHandler ?? InlineResourceTypeHandler('directory'),
    );
  }
}

// ===========================================================================
// ResourceBlockHandler
// ===========================================================================

/// Handles `resource { ... }` blocks inside `resources`.
///
/// All resource properties (`source`, `destination`, `type`, `id`, `status`,
/// `sha256`) are registered as scoped commands that write to the context.
/// After children are processed, the handler materializes the [ResourceModel].
class ResourceBlockHandler extends i3.BaseBlockHandler {
  /// Optional custom [ActionsBlockHandler] to use instead of the default.
  /// The v2 pipeline provides one that registers real [ActionBlock] subclasses.
  final ActionsBlockHandler? customActionsHandler;

  /// Event bus for emitting resource-level lifecycle events.
  /// When set, [ResourceCompletedEvent] is emitted.
  final EventBus? eventBus;

  ResourceBlockHandler({this.customActionsHandler, this.eventBus});

  @override
  String get blockType => 'resource';

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['resourceBuilder'] = ResourceBuilder();
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerScopedBlockHandler(
      'actions',
      customActionsHandler ??
          ActionsBlockHandler(
            customActionHandlers: _v1ActionCollectorHandlers(),
          ),
    );
    registry.registerScopedBlockHandler('template', TemplateBlockHandler());
    registry.registerScopedBlockHandler(
      'subcommands',
      SubCommandsBlockHandler(),
    );
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final builder = context.options['resourceBuilder'] as ResourceBuilder;

    builder.source =
        (context.getVariable('source') as String?) ?? builder.source;
    builder.destination =
        (context.getVariable('destination') as String?) ?? builder.destination;
    builder.type = (context.getVariable('type') as String?) ?? builder.type;
    builder.id = (context.getVariable('id') as String?) ?? builder.id;
    builder.status = context.getVariable('status') as String?;
    builder.sha256 = context.getVariable('sha256') as String?;

    // Emit resource-level events for the v2 pipeline.
    final resourceId = (builder.id?.isNotEmpty ?? false)
        ? builder.id!
        : builder.type ?? 'resource';
    if (builder.actions.isNotEmpty) {
      eventBus?.emit(
        ResourceCompletedEvent(
          moduleId: 'config-manager',
          resourceId: resourceId,
          resourceType: builder.type ?? 'unknown',
          source: builder.source ?? '',
          destination: builder.destination ?? '',
          completedActions: builder.actions.length,
          totalActions: builder.actions.length,
          duration: Duration.zero,
        ),
      );
    }

    // v1 path: add to ConfigBuilder if present.
    final configBuilder = context.globalContext.options['configBuilder'];
    if (configBuilder is ConfigBuilder) {
      configBuilder.resources.add(builder.build());
    }
  }
}

// ===========================================================================
// InlineResourceTypeHandler
// ===========================================================================

/// Handles inline `file { ... }` or `directory { ... }` blocks inside
/// `resources`. This is a shorthand alternative to `resource { type = "..."
/// ... }`.
class InlineResourceTypeHandler extends i3.BaseBlockHandler {
  @override
  final String blockType;

  /// Optional custom [ActionsBlockHandler] to use instead of the default.
  final ActionsBlockHandler? customActionsHandler;

  InlineResourceTypeHandler(this.blockType, {this.customActionsHandler});

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['resourceBuilder'] = ResourceBuilder()..type = blockType;
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerScopedBlockHandler(
      'actions',
      customActionsHandler ??
          ActionsBlockHandler(
            customActionHandlers: _v1ActionCollectorHandlers(),
          ),
    );
    registry.registerScopedBlockHandler('template', TemplateBlockHandler());
    registry.registerScopedBlockHandler(
      'subcommands',
      SubCommandsBlockHandler(),
    );
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final builder = context.options['resourceBuilder'] as ResourceBuilder;

    builder.source =
        (context.getVariable('source') as String?) ?? builder.source;
    builder.destination =
        (context.getVariable('destination') as String?) ?? builder.destination;
    builder.id = (context.getVariable('id') as String?) ?? builder.id;
    builder.status = context.getVariable('status') as String?;
    builder.sha256 = context.getVariable('sha256') as String?;

    // v1 path: add to ConfigBuilder if present.
    final configBuilder = context.globalContext.options['configBuilder'];
    if (configBuilder is ConfigBuilder) {
      configBuilder.resources.add(builder.build());
    }
  }
}

// ===========================================================================
// ActionsBlockHandler
// ===========================================================================

/// Handles `actions { ... }` blocks inside resource blocks.
///
/// Registers action type handlers from [customActionHandlers] as scoped block
/// handlers. The v2 pipeline passes actual [ActionBlock] subclasses that
/// execute directly. The v1 pipeline passes inline collector handlers that
/// build old [Action] model objects — but the v1 path is deprecated.
class ActionsBlockHandler extends i3.BaseBlockHandler {
  /// Map of action type keyword → [i3.BlockHandler] to register as scoped
  /// handlers under this `actions` block.
  final Map<String, i3.BlockHandler> customActionHandlers;

  ActionsBlockHandler({required this.customActionHandlers});

  @override
  String get blockType => 'actions';

  @override
  void handle(i3.Block block, i3.Context context) {
    // Nothing to do — child action blocks are dispatched to their scoped
    // handlers registered in [registerScopedCommands].
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    for (final entry in customActionHandlers.entries) {
      registry.registerScopedBlockHandler(entry.key, entry.value);
    }
  }
}

// ===========================================================================
// TemplateBlockHandler
// ===========================================================================

/// Handles `template { ... }` blocks inside resource blocks.
class TemplateBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'template';

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['templateVars'] = <String, dynamic>{};
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerCommand('template', _TemplateStrHandler());
    registry.registerScopedBlockHandler('vars', TemplateVarsBlockHandler());
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final templateStr = context.getVariable('template_str') as String?;
    final vars = context.options['templateVars'] as Map<String, dynamic>;

    if (templateStr != null) {
      var parentCtx = context.parentContext;
      while (parentCtx != null) {
        if (parentCtx.options['resourceBuilder'] is ResourceBuilder) {
          (parentCtx.options['resourceBuilder'] as ResourceBuilder).template =
              Template(template: templateStr, vars: Map.from(vars));
          break;
        }
        parentCtx = parentCtx.parentContext;
      }
    }
  }
}

/// Handles `vars { ... }` blocks inside `template`.
class TemplateVarsBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'vars';

  @override
  void handle(i3.Block block, i3.Context context) {
    // The vars block body consists of assignments that define variable values.
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final vars = <String, dynamic>{};
    for (final element in block.body) {
      if (element is i3.Assignment) {
        vars[element.variable] = element.values
            .map((v) => expandValue(v, context))
            .join(' ');
      }
    }
    // Push vars up to the template handler's context.
    final parentCtx = context.parentContext;
    if (parentCtx != null) {
      parentCtx.options['templateVars'] = vars;
    }
  }
}

// ===========================================================================
// SubCommandsBlockHandler
// ===========================================================================

/// Handles `subcommands { ... }` blocks inside resource blocks.
///
/// Sub-command entries have dynamic names (e.g., `exec { ... }`,
/// `install { ... }`) that cannot be known ahead of time, so this handler
/// processes its body with minimal manual iteration — the only exception
/// to the pure handler-driven pattern.
class SubCommandsBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'subcommands';

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['subCommands'] = <Command>[];
  }

  @override
  Future<void> processChildren(i3.Block block, i3.Context context) async {
    final processor =
        context.globalContext.options['_processor'] as i3.ConfigProcessor;

    for (final element in block.body) {
      if (element is i3.Command && element.block != null) {
        // Each command-with-block (e.g. exec { ... }) gets its own context
        // so property assignments don't leak between entries.
        processor.pushContext();
        try {
          await processor.currentState.process(element, processor);

          // Collect this entry's properties after the state machine processed
          // its body via scoped command handlers.
          final name = element.head;
          final cmd = _buildSubCommand(context, name);
          (context.options['subCommands'] as List<Command>).add(cmd);
        } finally {
          processor.popContext();
        }
      } else {
        // Let the state machine handle non-entry elements.
        processor.pushState(i3.InitialState());
        try {
          await processor.currentState.process(element, processor);
        } finally {
          processor.popState();
        }
      }
    }
  }

  Command _buildSubCommand(i3.Context context, String name) {
    final cb = CommandBuilder();
    cb.name = name;
    cb.id = context.getVariable('id') as String?;
    cb.command = context.getVariable('command') as String?;
    cb.status = context.getVariable('status') as String?;
    cb.timestamp = context.getVariable('timestamp') as String?;
    cb.sha256 = context.getVariable('sha256') as String?;

    final params = context.getVariable('parameters');
    if (params is List) {
      cb.parameters.addAll(params.cast<String>());
    } else if (params is String && params.isNotEmpty) {
      cb.parameters.addAll(params.split(' '));
    }
    return cb.build();
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    // Attach collected sub-commands to the parent ResourceBuilder.
    final commands = context.options['subCommands'] as List<Command>;
    var parentCtx = context.parentContext;
    while (parentCtx != null) {
      if (parentCtx.options['resourceBuilder'] is ResourceBuilder) {
        (parentCtx.options['resourceBuilder'] as ResourceBuilder).commands
            .addAll(commands);
        break;
      }
      parentCtx = parentCtx.parentContext;
    }
  }
}

// ===========================================================================
// CommandsBlockHandler
// ===========================================================================

/// Handles the top-level `commands { ... }` block.
///
/// Each `command <name> { ... }` entry has the name in the Command args, not
/// the block, so this handler overrides [processChildren] to extract the name
/// before delegating to the v2 state machine for child processing.
class CommandsBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'commands';

  @override
  void handle(i3.Block block, i3.Context context) {
    // Setup done in processChildren
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerScopedBlockHandler('command', CommandEntryBlockHandler());
  }

  @override
  Future<void> processChildren(i3.Block block, i3.Context context) async {
    final processor =
        context.globalContext.options['_processor'] as i3.ConfigProcessor;

    for (final element in block.body) {
      if (element is i3.Command && element.block != null) {
        // Extract the name from the command args, e.g.
        //   command install-dependencies { ... }
        //   → head='command', args[0]=BareArg('install-dependencies')
        final name = element.args.isNotEmpty
            ? expandValue(element.args[0], context)
            : element.head;

        // Store the name as a context variable before processing the entry.
        context.setVariable('name', name);

        // Let the state machine handle this command-with-block.
        // It will push/pop contexts and route to CommandEntryBlockHandler.
        processor.pushState(i3.InitialState());
        try {
          await processor.currentState.process(element, processor);
        } finally {
          processor.popState();
        }
      } else {
        processor.pushState(i3.InitialState());
        try {
          await processor.currentState.process(element, processor);
        } finally {
          processor.popState();
        }
      }
    }
  }
}

// ===========================================================================
// CommandEntryBlockHandler
// ===========================================================================

/// Handles `command <name> { ... }` blocks inside `commands`.
class CommandEntryBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'command';

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['commandBuilder'] = CommandBuilder();
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerCommand('parameters', _ParametersHandler());
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final builder = context.options['commandBuilder'] as CommandBuilder;
    final configBuilder =
        context.globalContext.options['configBuilder'] as ConfigBuilder;

    // Extract the command name from the identifier or head.
    // The block identifier carries the name from `command <name>`.
    builder.name = context.getVariable('name') as String? ?? builder.name;
    builder.id = (context.getVariable('id') as String?) ?? builder.id;
    builder.command = context.getVariable('command') as String?;
    builder.status = context.getVariable('status') as String?;
    builder.timestamp = context.getVariable('timestamp') as String?;
    builder.sha256 = context.getVariable('sha256') as String?;

    final params = context.getVariable('parameters');
    if (params is List) {
      builder.parameters.addAll(params.cast<String>());
    } else if (params is String && params.isNotEmpty) {
      builder.parameters.addAll(params.split(' '));
    }

    configBuilder.commands.add(builder.build());
  }
}

// ===========================================================================
// PackagesBlockHandler
// ===========================================================================

/// Handles the top-level `packages { ... }` block.
class PackagesBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'packages';

  @override
  void handle(i3.Block block, i3.Context context) {
    // Children are processed by the state machine automatically.
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerScopedBlockHandler('package', PackageEntryBlockHandler());
  }
}

// ===========================================================================
// PackageEntryBlockHandler
// ===========================================================================

/// Handles `package { ... }` blocks inside `packages`.
class PackageEntryBlockHandler extends i3.BaseBlockHandler {
  @override
  String get blockType => 'package';

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['packageBuilder'] = PackageBuilder();
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {}

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final pb = context.options['packageBuilder'] as PackageBuilder;
    final configBuilder =
        context.globalContext.options['configBuilder'] as ConfigBuilder;

    pb.name = (context.getVariable('name') as String?) ?? pb.name;

    if (pb.name == null || pb.name!.isEmpty) {
      throw ActionFailedException('Package block requires a "name" assignment');
    }

    pb.manager = (context.getVariable('manager') as String?) ?? pb.manager;
    pb.version = (context.getVariable('version') as String?) ?? pb.version;
    pb.scope = (context.getVariable('scope') as String?) ?? pb.scope;
    pb.id = (context.getVariable('id') as String?) ?? pb.id;
    pb.status = context.getVariable('status') as String?;
    pb.timestamp = context.getVariable('timestamp') as String?;
    pb.sha256 = context.getVariable('sha256') as String?;

    configBuilder.packages.add(pb.build());
  }
}

// ===========================================================================
// ScriptsBlockHandler
// ===========================================================================

/// Handles `pre_apply_scripts { ... }` and `post_apply_scripts { ... }`.
class ScriptsBlockHandler extends i3.BaseBlockHandler {
  @override
  final String blockType;

  ScriptsBlockHandler(this.blockType);

  @override
  void handle(i3.Block block, i3.Context context) {
    context.options['scripts'] = <String>[];
  }

  @override
  Future<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    final scripts = <String>[];
    for (final element in block.body) {
      switch (element) {
        case i3.Command cmd:
          for (final arg in cmd.args) {
            final value = expandValue(arg, context);
            if (value.isNotEmpty) scripts.add(value);
          }
        case i3.Assignment assign:
          for (final value in assign.values) {
            final s = expandValue(value, context);
            if (s.isNotEmpty) scripts.add(s);
          }
        default:
          break;
      }
    }

    final configBuilder =
        context.globalContext.options['configBuilder'] as ConfigBuilder;
    if (blockType == 'pre_apply_scripts') {
      configBuilder.preApplyScripts.addAll(scripts);
    } else {
      configBuilder.postApplyScripts.addAll(scripts);
    }
  }
}

