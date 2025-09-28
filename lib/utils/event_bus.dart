import 'dart:async';

import 'package:configr/events/module_events.dart';

final eventBus = EventBus();

void emitEvent(ModuleEvent event) {
  eventBus.emit(event);
}

/// Event subscription for managing event listeners
class EventSubscription {
  final StreamSubscription<ModuleEvent> _subscription;

  EventSubscription(this._subscription);

  /// Cancel the subscription
  void cancel() {
    _subscription.cancel();
  }

  /// Check if the subscription is active
  bool get isActive => !_subscription.isPaused;
}

/// Enhanced event bus with filtering and subscription management
class EventBus {
  static final EventBus _instance = EventBus._internal();

  factory EventBus() => _instance;

  EventBus._internal();

  final _controller = StreamController<ModuleEvent>.broadcast();
  final List<EventSubscription> _subscriptions = [];
  final Map<ModuleEventType, List<StreamSubscription<ModuleEvent>>> _typedSubscriptions = {};

  /// Main event stream
  Stream<ModuleEvent> get stream => _controller.stream;

  /// Emit an event to the bus
  void emit(ModuleEvent event) {
    _controller.add(event);
  }

  /// Subscribe to all events
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

  /// Subscribe to specific event types
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
    
    // Track typed subscriptions
    for (final eventType in eventTypes) {
      _typedSubscriptions.putIfAbsent(eventType, () => []).add(subscription);
    }
    
    return eventSubscription;
  }

  /// Subscribe to events from specific modules
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

  /// Subscribe to events with custom filter
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

  /// Get a stream filtered by event type
  Stream<ModuleEvent> streamOfType(ModuleEventType eventType) {
    return _controller.stream.where((event) => event.eventType == eventType);
  }

  /// Get a stream filtered by module ID
  Stream<ModuleEvent> streamOfModule(String moduleId) {
    return _controller.stream.where((event) => event.moduleId == moduleId);
  }

  /// Get a stream filtered by correlation ID
  Stream<ModuleEvent> streamOfCorrelation(String correlationId) {
    return _controller.stream.where((event) => event.correlationId == correlationId);
  }

  /// Get statistics about the event bus
  EventBusStats getStats() {
    return EventBusStats(
      totalSubscriptions: _subscriptions.length,
      activeSubscriptions: _subscriptions.where((s) => s.isActive).length,
      typedSubscriptions: _typedSubscriptions.map(
        (type, subs) => MapEntry(type.name, subs.length),
      ),
    );
  }

  /// Clear all subscriptions
  void clearSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _typedSubscriptions.clear();
  }

  /// Dispose the event bus
  void dispose() {
    clearSubscriptions();
    _controller.close();
  }
}

/// Statistics about the event bus
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
