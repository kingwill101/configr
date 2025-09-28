import 'package:configr/events/module_events.dart';

abstract class UIHandler {
  void handleEvent(ModuleEvent event);
  void start();
  void stop();
}
