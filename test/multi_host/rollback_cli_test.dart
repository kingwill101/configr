import 'package:test/test.dart';
import 'package:configr/src/cli/commands/rollback.dart';

void main() {
  group('RollbackCommand', () {
    test('registers --host flag', () {
      final cmd = RollbackCommand();
      final option = cmd.argParser.options['host'];
      expect(option, isNotNull);
      expect(option!.help, contains('host'));
    });

    test('registers --count flag', () {
      final cmd = RollbackCommand();
      expect(cmd.argParser.options.containsKey('count'), isTrue);
    });

    test('parses --host value from args', () {
      final cmd = RollbackCommand();
      final result = cmd.argParser.parse(['--host', 'web-01']);
      expect(result['host'], equals('web-01'));
    });

    test('parses --host and --count together', () {
      final cmd = RollbackCommand();
      final result = cmd.argParser.parse(['--host', 'db-01', '--count', '3']);
      expect(result['host'], equals('db-01'));
      expect(result['count'], equals('3'));
    });
  });
}
