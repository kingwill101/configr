import 'dart:async';
import 'dart:math';

import 'package:configr/events/module_events.dart';
import 'package:configr/ui/handlers/cli_handler.dart';
import 'package:configr/utils/event_bus.dart';

void main() {
  CLIHandler uiHandler = CLIHandler();
  EventBus().stream.listen((event) {
    uiHandler.handleEvent(event);
  });

  uiHandler.start();

  emitEvent(StartedEvent(message: "Event started", moduleId: "app"));
  emitEvent(StatusUpdateEvent(level: StatusEvent.info, message: "Test message"));

  int progress1 = 0;
  int progress2 = 0;
  int progress3 = 0;

  Timer.periodic(Duration(milliseconds: 500), (Timer timer) {
    progress1 += Random().nextInt(15);
    progress2 += Random().nextInt(15);
    progress3 += Random().nextInt(15);
    emitEvent(ProgressEvent(moduleId: "app", current: progress1, total: 100));
    emitEvent(ProgressEvent(moduleId: "mod2", current: progress2, total: 100));
    emitEvent(ProgressEvent(moduleId: "mod3", current: progress3, total: 100));
    emitEvent(StatusUpdateEvent(
        moduleId: 'test-module${Random().nextInt(10)}',
        level: StatusEvent.warning,
        message: 'Test message'));
    if (progress1 >= 100 && progress2 >= 100 && progress3 >= 100) {
      timer.cancel();
    }
  });

  Timer.periodic(Duration(seconds: 6), (Timer timer) {
    emitEvent(CompletedEvent(message: "Event completed", moduleId: "app"));
    uiHandler.stop();
    timer.cancel();
  });
}
