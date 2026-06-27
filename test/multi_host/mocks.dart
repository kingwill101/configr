import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/events/module_events.dart';

/// A mock EventBus that records all emitted events for test assertions.
class MockEventBus extends EventBus {
  final List<ModuleEvent> emittedEvents = [];

  MockEventBus() : super() {
    stream.listen((event) {
      emittedEvents.add(event);
    });
  }

  /// Run a function and wait for async event propagation.
  Future<void> runWith(Future<void> Function() action) async {
    await action();
    await Future.delayed(Duration.zero);
  }

  /// Find the first event of type [T].
  T? eventOfType<T extends ModuleEvent>() {
    for (final event in emittedEvents) {
      if (event is T) return event;
    }
    return null;
  }

  /// Find all events of type [T].
  List<T> eventsOfType<T extends ModuleEvent>() {
    return emittedEvents.whereType<T>().toList();
  }
}

/// Records hosts that were "executed" for test assertions.
class MockExecutionRecorder {
  final List<String> executedHosts = [];
  final List<String> failedHosts = [];

  /// Create an executeOnHost callback that succeeds for all hosts.
  Future<void> Function(dynamic host) successCallback() {
    return (host) async {
      executedHosts.add(host is String ? host : '${host.name}');
    };
  }

  /// Create an executeOnHost callback that fails for specific hosts.
  Future<void> Function(dynamic host) failOnHosts(List<String> failNames) {
    return (host) async {
      final name = host is String ? host : '${host.name}';
      executedHosts.add(name);
      if (failNames.contains(name)) {
        failedHosts.add(name);
        throw Exception('Execution failed for $name');
      }
    };
  }
}
