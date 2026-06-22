import 'package:test/test.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/events/module_events.dart';

void main() {
  late EventBus eventBus;

  setUp(() {
    eventBus = EventBus();
  });

  test('EventBus emits events to subscribers', () async {
    final events = <ModuleEvent>[];

    eventBus.stream.listen((event) {
      events.add(event);
    });

    final testEvent = StartedEvent(
      moduleId: 'test-module',
      message: 'Test started'
    );

    emitEvent(testEvent);

    await Future.delayed(Duration.zero);

    expect(events.length, equals(1));
    expect(events.first.moduleId, equals('test-module'));
    expect(events.first is StartedEvent, isTrue);
    expect((events.first as StartedEvent).message, equals('Test started'));
  });

  test('Multiple subscribers receive same events', () async {
    final events1 = <ModuleEvent>[];
    final events2 = <ModuleEvent>[];

    eventBus.stream.listen((event) => events1.add(event));
    eventBus.stream.listen((event) => events2.add(event));

    final testEvent = ProgressEvent(
      moduleId: 'test-module',
      current: 50,
      total: 100
    );

    emitEvent(testEvent);

    await Future.delayed(Duration.zero);

    expect(events1.length, equals(1));
    expect(events2.length, equals(1));
    expect(events1.first is ProgressEvent, isTrue);
    expect(events2.first is ProgressEvent, isTrue);
    expect((events1.first as ProgressEvent).current, equals(50));
    expect((events1.first as ProgressEvent).total, equals(100));
  });
}