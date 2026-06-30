import 'package:configr/src/cli/commands/base_command.dart';
import 'package:configr/configr.dart';
import 'package:test/test.dart';

class TestCommand extends BaseCommand {
  TestCommand() {
    argParser.addFlag('test-flag', help: 'A test flag');
    argParser.addOption('test-option', help: 'A test option');
  }

  @override
  String get name => 'test';

  @override
  String get description => 'A test command';

  @override
  Future<void> executeCommand() async {}
}

void main() {
  group('BaseCommand', () {
    late TestCommand command;
    late ConfigrRuntime runtime;

    setUp(() {
      command = TestCommand();

      runtime = ConfigrRuntime(
        ConfigrConfig(privilegeEscalation: NoPrivilegeEscalation()),
      );
    });

    test('should have correct name and description', () {
      expect(command.name, equals('test'));
      expect(command.description, equals('A test command'));
    });

    test('should throw error when runtime is not set', () async {
      expect(() => command.run(), throwsStateError);
    });

    test('should work when runtime is set', () async {
      command.runtime = runtime;
      await expectLater(command.run(), completes);
    });

    test('should allow setting and getting runtime', () {
      expect(() => command.runtime = runtime, returnsNormally);
      expect(command.runtime, equals(runtime));
    });

    test('should have access to argParser', () {
      expect(command.argParser, isNotNull);
      expect(command.argParser.options.containsKey('test-flag'), isTrue);
      expect(command.argParser.options.containsKey('test-option'), isTrue);
    });
  });
}
