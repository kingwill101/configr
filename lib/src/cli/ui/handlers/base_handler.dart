import 'package:configr/src/events/module_events.dart';

abstract class UIHandler {
  void handleEvent(ModuleEvent event);
  void start();
  void stop();
  
  // Interactive input methods
  void enableInteractiveMode();
  void disableInteractiveMode();
  void enablePasswordPromptMode();
  void disablePasswordPromptMode();
  
  // Interactive prompt methods
  String prompt(String message, {String? defaultValue});
  bool confirm(String message, {bool defaultValue = false});
  T select<T>(String message, List<T> options, {T? defaultValue});
  String promptPassword(String message);
  void showMessage(String message);
  void showWarning(String message);
  void showError(String message);
  void showSuccess(String message);
}
