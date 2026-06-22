import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/modules/resource/resource_module.dart';

class FileEchoModule extends ResourceModule {
  FileEchoModule(super.file, super.action, {super.fileSystem, super.eventBus});

  String get message => action.properties['message'] ?? '';
  bool get color => action.properties['color'] ?? true;
  bool get verbose => action.properties['verbose'] ?? false;
  String get level => action.properties['level'] ?? 'info';

  @override
  Future<void> execute() async {
    if (verbose) {
      emitEvent(StatusUpdateEvent(
        moduleId: action.id,
        message: 'Echo module configuration:\nMessage: $message\nColor: $color\nLevel: $level',
        level: StatusEvent.info
      ));
    }

    switch (level) {
      case 'info':
        emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          message: message,
          level: StatusEvent.info
        ));
        break;
      case 'warning':
        emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          message: message,
          level: StatusEvent.warning
        ));
        break;
      case 'error':
        emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          message: message,
          level: StatusEvent.error
        ));
        break;
      case 'debug':
        emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          message: message,
          level: StatusEvent.debug
        ));
        break;
      default:
        emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          message: message,
          level: StatusEvent.info
        ));
    }
  }
}