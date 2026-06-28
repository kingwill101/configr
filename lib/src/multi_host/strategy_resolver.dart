import 'package:configr/src/multi_host/strategy.dart' show ExecutionStrategy;
import 'package:configr/src/multi_host/strategies/linear_strategy.dart';
import 'package:configr/src/multi_host/strategies/serial_strategy.dart';
import 'package:configr/src/multi_host/strategies/parallel_strategy.dart';

class UnknownStrategyException implements Exception {
  final String name;
  const UnknownStrategyException(this.name);
  @override
  String toString() => 'Unknown strategy: "$name". '
      'Available: linear, serial, parallel';
}

/// Resolves a strategy name to its implementation instance.
class StrategyResolver {
  final LinearStrategy linear;
  final SerialStrategy serial;
  final ParallelStrategy parallel;

  StrategyResolver({
    LinearStrategy? linear,
    SerialStrategy? serial,
    ParallelStrategy? parallel,
  })  : linear = linear ?? LinearStrategy(),
        serial = serial ?? SerialStrategy(),
        parallel = parallel ?? ParallelStrategy();

  ExecutionStrategy strategyFor(String name) {
    switch (name.toLowerCase()) {
      case 'linear':
        return linear;
      case 'serial':
        return serial;
      case 'parallel':
        return parallel;
      default:
        throw UnknownStrategyException(name);
    }
  }
}
