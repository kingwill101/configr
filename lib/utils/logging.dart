import 'package:configr/events/module_events.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:file/file.dart';
import 'package:logging/logging.dart';
import 'package:configr/utils/fs.dart';

final logger = Logger('configr');

void initLogging() {
  Logger.root.level = Level.WARNING; // Only show warnings and errors
  Logger.root.onRecord.listen((record) {
    // Only emit events for warnings and errors, not info messages
    if (record.level >= Level.WARNING) {
      final level = switch (record.level) {
        Level.WARNING => StatusEvent.warning,
        Level.SEVERE => StatusEvent.error,
        Level.SHOUT => StatusEvent.error,
        _ => StatusEvent.info,
      };
      emitEvent(StatusUpdateEvent(
          level: level, message: record.message, moduleId: "logger"));
    }

    // Still log everything to file for debugging
    final logFile = fs.file('app.log');
    final StringBuffer logBuffer = StringBuffer();
    logBuffer
        .writeln('\n${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      logBuffer.writeln('\nError: ${record.error}');
    }
    if (record.stackTrace != null) {
      logBuffer.writeln('\nStackTrace: ${record.stackTrace}');
    }
    logFile.writeAsStringSync(logBuffer.toString(), mode: FileMode.append);
  });
}
