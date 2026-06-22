// CLI commands are in cli/commands/ - using relative imports
import '../../cli/commands/base_command.dart';
import 'package:configr/configr.dart';
import 'package:test/test.dart';

class TestCommand extends BaseCommand {
  TestCommand() {
    argParser.addFlag('test-flag', help: 'A test flag');
    argParser.addOption('test-option', help: 'A test option');
  }

  String get name => 'test';

  String get description => 'A test command';

  void executeCommand() {}
}

void main() {
  group('BaseCommand', () {
    late TestCommand command;
    late ConfigManager configManager;

    setUp(() {
      command = TestCommand();

      configManager = ConfigManager(
        configrConfig: ConfigrConfig(
          privilegeEscalation: NoPrivilegeEscalation(),
        ),
      );
    });

    test('should have correct name and description', () {
      expect(command.name, equals('test'));
      expect(command.description, equals('A test command'));
    });

    test('should throw error when configManager is not set', () {
      expect(() => command.run(), throwsStateError);
    });

    test('should work when configManager is set', () {
      command.configManager = configManager;
      expect(() => command.run(), returnsNormally);
    });

    test('should allow setting and getting configManager', () {
      expect(() => command.configManager = configManager, returnsNormally);
      expect(command.configManager, equals(configManager));
    });

    test('should have access to argParser', () {
      expect(command.argParser, isNotNull);
      expect(command.argParser.options.containsKey('test-flag'), isTrue);
      expect(command.argParser.options.containsKey('test-option'), isTrue);
    });
  });
}
