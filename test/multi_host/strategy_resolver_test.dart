import 'package:test/test.dart';
import 'package:configr/src/multi_host/strategy_resolver.dart';
import 'package:configr/src/multi_host/strategies/linear_strategy.dart';
import 'package:configr/src/multi_host/strategies/serial_strategy.dart';
import 'package:configr/src/multi_host/strategies/parallel_strategy.dart';

void main() {
  group('StrategyResolver', () {
    late StrategyResolver resolver;

    setUp(() {
      resolver = StrategyResolver();
    });

    test('returns LinearStrategy for "linear"', () {
      expect(resolver.strategyFor('linear'), isA<LinearStrategy>());
    });

    test('returns SerialStrategy for "serial"', () {
      expect(resolver.strategyFor('serial'), isA<SerialStrategy>());
    });

    test('returns ParallelStrategy for "parallel"', () {
      expect(resolver.strategyFor('parallel'), isA<ParallelStrategy>());
    });

    test('is case-insensitive', () {
      expect(resolver.strategyFor('LINEAR'), isA<LinearStrategy>());
      expect(resolver.strategyFor('Serial'), isA<SerialStrategy>());
    });

    test('throws UnknownStrategyException for unknown names', () {
      expect(
        () => resolver.strategyFor('unknown'),
        throwsA(isA<UnknownStrategyException>()),
      );
    });

    test('UnknownStrategyException has helpful message', () {
      try {
        resolver.strategyFor('foo');
      } catch (e) {
        expect(e.toString(), contains('foo'));
        expect(e.toString(), contains('linear'));
        expect(e.toString(), contains('serial'));
        expect(e.toString(), contains('parallel'));
      }
    });
  });
}
