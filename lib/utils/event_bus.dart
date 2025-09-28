import 'dart:async';

import 'package:configr/events/module_events.dart';

final eventBus = EventBus();

void emitEvent(ModuleEvent event) {
  eventBus.emit(event);
}

class EventBus {
  static final EventBus _instance = EventBus._internal();

  factory EventBus() => _instance;

  EventBus._internal();

  final _controller = StreamController<ModuleEvent>.broadcast();

  Stream<ModuleEvent> get stream => _controller.stream;

  void emit(ModuleEvent event) {
    _controller.add(event);
  }
}
