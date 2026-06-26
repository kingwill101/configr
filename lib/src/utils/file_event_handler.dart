import 'dart:convert';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/file.dart';

/// Subscribes to an [EventBus] and writes every event as a JSON line to a
/// session log file.
///
/// Each line is a JSON object produced by [ModuleEvent.toStructuredData]() so
/// the result is parseable as [JSON Lines](https://jsonlines.org/).  A
/// `session` line marks the start and end of each run.
///
/// ```text
/// {"session":"start","timestamp":"2026-06-25T12:00:00.000Z"}
/// {"eventType":"started","moduleId":"...","message":"..."}
/// ...
/// {"session":"end","timestamp":"2026-06-25T12:00:05.000Z"}
/// ```
class FileEventHandler {
  final EventBus _eventBus;
  final File _logFile;
  EventSubscription? _subscription;

  FileEventHandler({
    required this._eventBus,
    required this._logFile,
  });

  /// Start listening for events and writing them to the file.
  void start() {
    _logFile.parent.createSync(recursive: true);
    _writeLine(<String, dynamic>{
      'session': 'start',
      'timestamp': DateTime.now().toIso8601String(),
    });
    _subscription = _eventBus.subscribe(_onEvent);
  }

  void _onEvent(ModuleEvent event) {
    _writeLine(event.toStructuredData());
  }

  void _writeLine(Map<String, dynamic> data) {
    _logFile.writeAsStringSync(
      '${jsonEncode(data)}\n',
      mode: FileMode.append,
    );
  }

  /// Stop listening and write a session-end marker.
  void stop() {
    _subscription?.cancel();
    _writeLine(<String, dynamic>{
      'session': 'end',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
