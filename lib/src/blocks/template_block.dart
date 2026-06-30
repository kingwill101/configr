import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/reader/handlers/configr_handlers.dart'
    show TemplateVarsBlockHandler;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:liquify/liquify.dart' as liquify;

/// Block handler for the `template` config action.
///
/// Renders Liquid templates with variables and writes the output
/// to the destination path.
///
/// ```i3
/// template {
///   source = "/path/to/template.liquid"
///   destination = "/path/to/output"
///   template_vars = { name: "world", count: 42 }
///   validate = true
///   backup_original = true
/// }
/// ```
class TemplateBlock extends ActionBlock {
  @override
  String get blockType => 'template';

  // ---------------------------------------------------------------------------
  // Template-specific properties
  // ---------------------------------------------------------------------------

  String format = 'mustache';
  Map<String, dynamic> templateVars = {};
  bool validateTemplate = true;
  bool backupOriginal = false;
  String backupSuffix = '.backup';

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  String? originalContent;
  String? templateContent;

  /// When true, the template is rendered in-memory for a parent resource
  /// instead of writing to disk.
  bool _insideResource = false;

  /// The parent resource context to store rendered content on.
  i3.Context? _resourceContext;

  TemplateBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  void resetState() {
    super.resetState();
    _insideResource = false;
    _resourceContext = null;
    originalContent = null;
    templateContent = null;
    templateVars = {};
    validateTemplate = true;
    backupOriginal = false;
    backupSuffix = '.backup';
    format = 'mustache';
  }

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerCommand('template', _TemplatePathHandler());
    registry.registerScopedBlockHandler('vars', TemplateVarsBlockHandler());
  }

  @override
  Map<String, String> get additionalProperties => {
    if (format != 'mustache') 'format': format,
    if (backupSuffix != '.backup') 'backup_suffix': backupSuffix,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!validateTemplate) 'validate': validateTemplate,
    if (backupOriginal) 'backup_original': backupOriginal,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    // Detect if this template block is inside a resource — if so, render
    // in-memory and store rendered content for child actions to consume.
    _insideResource = false;
    _resourceContext = null;
    var ctx = context.parentContext;
    while (ctx != null) {
      if (ctx.options.containsKey('resourceBuilder')) {
        _insideResource = true;
        _resourceContext = ctx;
        break;
      }
      ctx = ctx.parentContext;
    }

    // Support both source (v2) and template_str (v1 compat) for the
    // template file path. template_str is set by the `template` command
    // handler when using `template = "..."` syntax.
    // This must override any value set by the base class's backward-compat
    // shim (which sets source = destination when source is empty).
    final templateStr = context.getVariable('template_str') as String?;
    if (templateStr != null) {
      source = templateStr;
    }

    format = (context.getVariable('format') as String?) ?? format;
    // Collect template variables from context.
    // TemplateVarsBlockHandler stores them in context.options['templateVars'],
    // not as a context variable (setVariable/getVariable).
    final vars = context.options['templateVars'] as Map<String, dynamic>?;
    if (vars != null) {
      templateVars = vars.cast<String, dynamic>();
    }

    // Template variable keys are typically passed as a `template_vars` map,
    // or as individual assignment variables. We pick up what's available.
    // Explicit template variables override auto-detected ones.

    validateTemplate = switch (context.getVariable('validate')) {
      false || 'false' => false,
      _ => true,
    };

    backupOriginal = switch (context.getVariable('backup_original')) {
      true || 'true' => true,
      _ => false,
    };

    backupSuffix =
        (context.getVariable('backup_suffix') as String?) ?? '.backup';
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting template processing for $source → $destination',
      ),
    );

    final sourceFile = fileSystem.file(source);
    if (!await sourceFile.exists()) {
      throw ActionFailedException(
        'Template file does not exist: $source',
        moduleId: id,
      );
    }

    try {
      // Read template
      templateContent = await sourceFile.readAsString();

      // Validate template if requested
      if (validateTemplate) {
        await _validateTemplate(templateContent!);
      }

      // Render template
      renderedContent = await _renderTemplate(templateContent!, templateVars);

      if (_insideResource) {
        // In-memory mode: store rendered content on the resource context
        // so child actions (copy, permissions, etc.) can consume it.
        _resourceContext!.setVariable('_rendered_content', renderedContent);
        emitEvent(
          CompletedEvent(
            moduleId: id,
            message: 'Template rendered in-memory for resource actions',
          ),
        );
      } else {
        // File mode: write rendered content to destination
        final destFile = fileSystem.file(destination);
        if (await destFile.exists()) {
          originalContent = await destFile.readAsString();
        }

        // Ensure destination directory exists
        final destDir = destFile.parent;
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }

        // Backup original if exists
        if (await destFile.exists() && backupOriginal) {
          final backupFile = fileSystem.file('${destFile.path}$backupSuffix');
          await destFile.copy(backupFile.path);
        }

        // Write rendered content
        await destFile.writeAsString(renderedContent!);

        emitEvent(
          CompletedEvent(
            moduleId: id,
            message: 'Template processing completed',
          ),
        );
      }
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Template processing failed: $e'),
      );
      throw ActionFailedException(
        'Failed to process template $source → $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    if (_insideResource) {
      // In-memory mode: nothing was written to disk, so no rollback needed.
      return;
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Rolling back template processing'),
    );

    try {
      final destFile = fileSystem.file(destination);

      if (originalContent != null) {
        await destFile.writeAsString(originalContent!);
      } else if (await destFile.exists()) {
        await destFile.delete();
      }

      // Remove backup file
      final backupFile = fileSystem.file('$destination$backupSuffix');
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Template rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Template rollback failed: $e'),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _validateTemplate(String content) async {
    try {
      liquify.Template.parse(content, data: <String, dynamic>{});
    } catch (e) {
      throw ActionFailedException(
        'Template validation failed: $e',
        moduleId: id,
      );
    }
  }

  Future<String> _renderTemplate(
    String content,
    Map<String, dynamic> vars,
  ) async {
    try {
      final template = liquify.Template.parse(content, data: vars);
      return template.render();
    } catch (e) {
      throw ActionFailedException(
        'Template rendering failed: $e',
        moduleId: id,
      );
    }
  }
}

/// Command handler for `template = "..."` syntax inside a template block.
///
/// Sets the `template_str` context variable to the provided file path.
class _TemplatePathHandler extends i3.BaseCommandHandler<String> {
  @override
  String get commandName => 'template';

  @override
  String? handle(i3.Command command, i3.Context context) {
    final value = getArgAsString(command, 0, context);
    context.setVariable('template_str', value);
    return value;
  }
}
