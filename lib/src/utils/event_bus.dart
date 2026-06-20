import 'dart:async';

import 'package:configr/src/events/module_events.dart';

EventBus _defaultEventBus = EventBus();

EventBus get eventBus => _defaultEventBus;

void setDefaultEventBus(EventBus bus) {
  _defaultEventBus = bus;
}

void emitEvent(ModuleEvent event) {
  _defaultEventBus.emit(event);
}

class EventSubscription {
  final StreamSubscription<ModuleEvent> _subscription;

  EventSubscription(this._subscription);

  void cancel() {
    _subscription.cancel();
  }

  bool get isActive => !_subscription.isPaused;
}

class EventBus {
  final StreamController<ModuleEvent> _controller;

  EventBus({StreamController<ModuleEvent>? controller})
      : _controller = controller ?? StreamController<ModuleEvent>.broadcast();

  final List<EventSubscription> _subscriptions = [];
  final Map<ModuleEventType, List<StreamSubscription<ModuleEvent>>> _typedSubscriptions = {};

  Stream<ModuleEvent> get stream => _controller.stream;

  void emit(ModuleEvent event) {
    _controller.add(event);
  }

  EventSubscription subscribe(
    void Function(ModuleEvent) onEvent, {
    void Function(Object)? onError,
    void Function()? onDone,
  }) {
    final subscription = _controller.stream.listen(
      onEvent,
      onError: onError,
      onDone: onDone,
    );

    final eventSubscription = EventSubscription(subscription);
    _subscriptions.add(eventSubscription);
    return eventSubscription;
  }

  EventSubscription subscribeToTypes(
    List<ModuleEventType> eventTypes,
    void Function(ModuleEvent) onEvent, {
    void Function(Object)? onError,
    void Function()? onDone,
  }) {
    final subscription = _controller.stream
        .where((event) => eventTypes.contains(event.eventType))
        .listen(
          onEvent,
          onError: onError,
          onDone: onDone,
        );

    final eventSubscription = EventSubscription(subscription);
    _subscriptions.add(eventSubscription);

    for (final eventType in eventTypes) {
      _typedSubscriptions.putIfAbsent(eventType, () => []).add(subscription);
    }

    return eventSubscription;
  }

  EventSubscription subscribeToModules(
    List<String> moduleIds,
    void Function(ModuleEvent) onEvent, {
    void Function(Object)? onError,
    void Function()? onDone,
  }) {
    final subscription = _controller.stream
        .where((event) => moduleIds.contains(event.moduleId))
        .listen(
          onEvent,
          onError: onError,
          onDone: onDone,
        );

    final eventSubscription = EventSubscription(subscription);
    _subscriptions.add(eventSubscription);
    return eventSubscription;
  }

  EventSubscription subscribeWithFilter(
    bool Function(ModuleEvent) filter,
    void Function(ModuleEvent) onEvent, {
    void Function(Object)? onError,
    void Function()? onDone,
  }) {
    final subscription = _controller.stream
        .where(filter)
        .listen(
          onEvent,
          onError: onError,
          onDone: onDone,
        );

    final eventSubscription = EventSubscription(subscription);
    _subscriptions.add(eventSubscription);
    return eventSubscription;
  }

  Stream<ModuleEvent> streamOfType(ModuleEventType eventType) {
    return _controller.stream.where((event) => event.eventType == eventType);
  }

  Stream<ModuleEvent> streamOfModule(String moduleId) {
    return _controller.stream.where((event) => event.moduleId == moduleId);
  }

  Stream<ModuleEvent> streamOfCorrelation(String correlationId) {
    return _controller.stream.where((event) => event.correlationId == correlationId);
  }

  EventBusStats getStats() {
    return EventBusStats(
      totalSubscriptions: _subscriptions.length,
      activeSubscriptions: _subscriptions.where((s) => s.isActive).length,
      typedSubscriptions: _typedSubscriptions.map(
        (type, subs) => MapEntry(type.name, subs.length),
      ),
    );
  }

  void clearSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _typedSubscriptions.clear();
  }

  void dispose() {
    clearSubscriptions();
    _controller.close();
  }
}

class EventBusStats {
  final int totalSubscriptions;
  final int activeSubscriptions;
  final Map<String, int> typedSubscriptions;

  const EventBusStats({
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.typedSubscriptions,
  });

  @override
  String toString() {
    return 'EventBusStats(total: $totalSubscriptions, active: $activeSubscriptions, typed: $typedSubscriptions)';
  }
}
