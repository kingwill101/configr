/// Configr - A powerful configuration management tool for dotfiles.
///
/// This library provides:
/// - Config parsing and management (i3, JSON, YAML formats)
/// - Resource modules (file, directory, backup, copy, etc.)
/// - Event-driven execution with rollback support
///
/// Example usage:
/// ```dart
/// import 'package:configr/configr.dart';
///
/// final config = ConfigrConfig();
/// final manager = ConfigManager(configrConfig: config);
/// await manager.load();
/// await manager.applyConfig();
/// ```

// Re-export everything from lib/src/
export 'src/models/config.dart';
export 'src/models/action.dart';
export 'src/models/file_model.dart';
export 'src/models/command.dart';
export 'src/models/package.dart';
export 'src/models/template.dart';
export 'src/models/lockfile_data.dart';

export 'src/config_manager.dart';
export 'src/configr_config.dart';

export 'src/utils/event_bus.dart';
export 'src/utils/logging.dart';
export 'src/utils/file_utils.dart';
export 'src/utils/config.dart';
export 'src/utils/privilege_escalation.dart';
export 'src/utils/lockfile_manager.dart';
export 'src/utils/template_renderer.dart';
export 'src/writer/i3_config_writer.dart';
export 'src/writer/i3_config_writer_v2.dart';

export 'src/modules/resource/resource_module.dart';
export 'src/modules/resource/backup.dart';
export 'src/modules/resource/copy.dart';
export 'src/modules/resource/delete.dart';
export 'src/modules/resource/permissions.dart';
export 'src/modules/resource/symlink.dart';
export 'src/modules/resource/template.dart';
export 'src/modules/resource/validate.dart';

export 'src/events/module_events.dart';

export 'src/exceptions.dart';

export 'src/format/config_format.dart';
export 'src/format/format_service.dart';

export 'src/configr_runtime.dart';
