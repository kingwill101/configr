/// Configr - A powerful configuration management tool for dotfiles and
/// system configuration.
///
/// This library provides:
/// - Config parsing and management via the i3config v2 format
/// - Action block pipeline (copy, delete, download, etc.)
/// - Event-driven execution with rollback support
///
/// Example usage:
/// ```dart
/// import 'package:configr/configr.dart';
///
/// final config = ConfigrConfig();
/// final runtime = ConfigrRuntime(config);
/// await runtime.apply();
/// ```
library;

export 'src/configr_config.dart';
export 'src/configr_runtime.dart';
export 'src/connection_config.dart';

export 'src/events/module_events.dart';
export 'src/exceptions.dart';

export 'src/format/config_format.dart';
export 'src/format/format_service.dart';

export 'src/models/config_options.dart';
export 'src/models/v2_lockfile_data.dart';

export 'src/utils/event_bus.dart';
export 'src/utils/file_event_handler.dart';
export 'src/utils/file_utils.dart';
export 'src/utils/fs.dart';
export 'src/utils/logging.dart';
export 'src/secrets/secrets.dart';
export 'src/utils/privilege_escalation.dart';

export 'src/writer/i3_config_writer_v2.dart';
