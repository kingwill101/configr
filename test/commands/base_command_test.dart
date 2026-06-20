import 'package:configr/commands/base_command.dart';
import 'package:configr/config_manager.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/privellage_escallation.dart';
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
  void executeCommand() {
    // Test implementation
  }
}

void main() {
  group('BaseCommand', () {
    late TestCommand command;
    late ConfigManager configManager;

    setUp(() {
      command = TestCommand();
      
      final privilegeEscalation = InteractiveSudoEscalation();
      configManager = ConfigManager(
        repoUrl: 'https://github.com/test/test.git',
        path: fs.currentDirectory.path,
        fileSystem: fs,
        privilegeEscalation: privilegeEscalation,
        configPath: 'test-config',
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
