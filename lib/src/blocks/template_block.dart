import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
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
  String? renderedContent;

  TemplateBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

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

    format = (context.getVariable('format') as String?) ?? format;
    // Collect template variables from context
    // Template vars can be set individually or as a map
    final vars = context.getVariable('template_vars');
    if (vars is Map) {
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

    // Store original content for rollback
    final destFile = fileSystem.file(destination);
    if (await destFile.exists()) {
      originalContent = await destFile.readAsString();
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
        CompletedEvent(moduleId: id, message: 'Template processing completed'),
      );
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
