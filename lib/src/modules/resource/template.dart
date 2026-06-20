import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:liquify/liquify.dart' as liquify;

/// Enhanced template module with advanced file generation from templates.
/// 
/// Features:
/// - Variable substitution with Liquid templating engine
/// - Conditional logic and loop constructs
/// - Multiple template formats support
/// - Template validation and error handling
/// - Progress tracking for batch operations
/// - Comprehensive event emission
/// - Rollback support
class FileTemplateModule extends ResourceModule {
  // State getters
  bool get templateFileExisted => state['templateFileExisted'] as bool? ?? false;
  String? get originalContent => state['originalContent'] as String?;
  String? get templateContent => state['templateContent'] as String?;
  String? get renderedContent => state['renderedContent'] as String?;
  Map<String, dynamic> get templateVars {
    final vars = state['templateVars'];
    if (vars == null) return {};
    if (vars is Map<String, dynamic>) return vars;
    if (vars is Map<dynamic, dynamic>) return _convertMap(vars);
    return {};
  }
  bool get validateTemplate => state['validateTemplate'] as bool? ?? true;
  bool get showProgress => state['showProgress'] as bool? ?? true;
  int get processedTemplates => state['processedTemplates'] as int? ?? 0;
  int get totalTemplates => state['totalTemplates'] as int? ?? 0;
  int get failedTemplates => state['failedTemplates'] as int? ?? 0;
  List<String> get includePatterns => (state['includePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  List<String> get excludePatterns => (state['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];
  String get templateEngine => state['templateEngine'] as String? ?? 'liquid';
  bool get backupOriginal => state['backupOriginal'] as bool? ?? false;
  String? get backupSuffix => state['backupSuffix'] as String? ?? '.backup';

  FileTemplateModule(super.file, super.action,
      {super.allowedActions = const ['template'], super.fileSystem, super.eventBus}) {
    updateState({
      'templateFileExisted': false,
      'originalContent': null,
      'templateContent': null,
      'renderedContent': null,
      'templateVars': {},
      'validateTemplate': true,
      'showProgress': true,
      'processedTemplates': 0,
      'totalTemplates': 0,
      'failedTemplates': 0,
      'includePatterns': [],
      'excludePatterns': [],
      'templateEngine': 'liquid',
      'backupOriginal': false,
      'backupSuffix': '.backup',
    });

    // Load configuration from action properties
    _loadConfiguration();
  }

  void _loadConfiguration() {
    final props = action.properties;
    
    // Extract template variables from action properties
    // Prefer explicit template_vars, fall back to extracting non-system properties
    final systemProps = {'status', 'timestamp', 'sha256', 'id', 'type', 'validate_template', 'show_progress', 'include_patterns', 'exclude_patterns', 'template_engine', 'backup_original', 'backup_suffix'};
    final templateVars = <String, dynamic>{};
    
    if (props.containsKey('template_vars')) {
      final vars = props['template_vars'];
      if (vars is Map<String, dynamic>) {
        templateVars.addAll(vars);
      } else if (vars is Map<dynamic, dynamic>) {
        templateVars.addAll(_convertMap(vars));
      }
    } else {
      for (final entry in props.entries) {
        if (!systemProps.contains(entry.key)) {
          templateVars[entry.key] = entry.value;
        }
      }
    }
    
    updateState({'templateVars': templateVars});
    
    if (props.containsKey('validate_template')) {
      updateState({'validateTemplate': props['validate_template']});
    }
    
    if (props.containsKey('show_progress')) {
      updateState({'showProgress': props['show_progress']});
    }
    
    if (props.containsKey('include_patterns')) {
      updateState({'includePatterns': props['include_patterns']});
    }
    
    if (props.containsKey('exclude_patterns')) {
      updateState({'excludePatterns': props['exclude_patterns']});
    }
    
    if (props.containsKey('template_engine')) {
      updateState({'templateEngine': props['template_engine']});
    }
    
    if (props.containsKey('backup_original')) {
      updateState({'backupOriginal': props['backup_original']});
    }
    
    if (props.containsKey('backup_suffix')) {
      updateState({'backupSuffix': props['backup_suffix']});
    }
  }

  /// Recursively convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map<dynamic, dynamic>) {
        result[key] = _convertMap(value);
      } else if (value is List) {
        result[key] = _convertList(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  /// Convert List with potential nested maps
  List<dynamic> _convertList(List list) {
    return list.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return _convertMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting template processing for ${source}',
      ),
    );

    try {
      await _processTemplate();
      
      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Template processing completed for ${source}',
        ),
      );
    } catch (e, stackTrace) {
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Template processing failed for ${source}: ${e.toString()}',
        ),
      );
      logger.severe('Template processing failed', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _processTemplate() async {
    final sourceFile = (fileSystem ?? fs).file(source);
    final destFile = (fileSystem ?? fs).file(destination);

    // Check if source template exists
    if (!sourceFile.existsSync()) {
      throw ActionFailedException('Template file does not exist: ${source}');
    }

    // Store original state for rollback
    updateState({
      'templateFileExisted': sourceFile.existsSync(),
      'originalContent': destFile.existsSync() ? destFile.readAsStringSync() : null,
    });

    // Read template content
    final templateContent = sourceFile.readAsStringSync();
    updateState({'templateContent': templateContent});

    // Validate template if requested
    if (validateTemplate) {
      await _validateTemplate(templateContent);
    }

    // Render template
    final renderedContent = await _renderTemplate(templateContent, templateVars);
    updateState({'renderedContent': renderedContent});

    // Create destination directory if needed
    final destDir = destFile.parent;
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }

    // Backup original file if it exists and backup is enabled
    if (destFile.existsSync() && backupOriginal) {
      final backupFile = (fileSystem ?? fs).file('${destFile.path}${backupSuffix}');
      destFile.copySync(backupFile.path);
      updateState({'backupFile': backupFile.path});
    }

    // Write rendered content to destination
    destFile.writeAsStringSync(renderedContent);

    // Update progress
    updateState({
      'processedTemplates': processedTemplates + 1,
    });

    logger.info('Template processed successfully: ${source} -> ${destination}');
  }

  Future<void> _validateTemplate(String templateContent) async {
    try {
      // Basic template validation
      if (templateEngine == 'liquid') {
        liquify.Template.parse(templateContent, data: <String, dynamic>{});
      } else {
        throw ActionFailedException('Unsupported template engine: $templateEngine');
      }
    } catch (e) {
      throw ActionFailedException('Template validation failed: ${e.toString()}');
    }
  }

  Future<String> _renderTemplate(String templateContent, Map<String, dynamic> vars) async {
    try {
      if (templateEngine == 'liquid') {
        final template = liquify.Template.parse(templateContent, data: vars);
        return template.render();
      } else {
        throw ActionFailedException('Unsupported template engine: $templateEngine');
      }
    } catch (e) {
      throw ActionFailedException('Template rendering failed: ${e.toString()}');
    }
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Rolling back template processing for ${source}',
      ),
    );

    try {
      final destFile = (fileSystem ?? fs).file(destination);

      if (originalContent != null) {
        // Restore original content
        destFile.writeAsStringSync(originalContent!);
        logger.info('Restored original content for: ${destination}');
      } else if (destFile.existsSync()) {
        // Remove the file if it didn't exist originally
        destFile.deleteSync();
        logger.info('Removed generated file: ${destination}');
      }

      // Remove backup file if it was created
      if (state.containsKey('backupFile')) {
        final backupFile = (fileSystem ?? fs).file(state['backupFile']);
        if (backupFile.existsSync()) {
          backupFile.deleteSync();
          logger.info('Removed backup file: ${backupFile.path}');
        }
      }

      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Template rollback completed for ${source}',
        ),
      );
    } catch (e, stackTrace) {
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Template rollback failed for ${source}: ${e.toString()}',
        ),
      );
      logger.severe('Template rollback failed', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getAdditionalState() async {
    return {
      'templateFileExisted': templateFileExisted,
      'originalContent': originalContent,
      'templateContent': templateContent,
      'renderedContent': renderedContent,
      'templateVars': templateVars,
      'validateTemplate': validateTemplate,
      'showProgress': showProgress,
      'processedTemplates': processedTemplates,
      'totalTemplates': totalTemplates,
      'failedTemplates': failedTemplates,
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'templateEngine': templateEngine,
      'backupOriginal': backupOriginal,
      'backupSuffix': backupSuffix,
    };
  }
}
