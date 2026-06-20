import 'package:configr/commands/add.dart';
import 'package:configr/commands/apply.dart';
import 'package:configr/commands/base_command.dart';
import 'package:configr/commands/diff.dart';
import 'package:configr/commands/edit.dart';
import 'package:configr/commands/format.dart';
import 'package:configr/commands/init.dart';
import 'package:configr/commands/rollback.dart';
import 'package:configr/commands/status.dart';
import 'package:configr/config_manager.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:test/test.dart';

void main() {
  group('Command Integration Tests', () {
    late ConfigManager configManager;

    setUp(() {
      final privilegeEscalation = InteractiveSudoEscalation();
      configManager = ConfigManager(
        repoUrl: 'https://github.com/test/test.git',
        path: fs.currentDirectory.path,
        fileSystem: fs,
        privilegeEscalation: privilegeEscalation,
        configPath: 'test-config',
      );
    });

    test('InitCommand should extend BaseCommand', () {
      final command = InitCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('init'));
      expect(command.description, isNotEmpty);
    });

    test('ApplyCommand should extend BaseCommand', () {
      final command = ApplyCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('apply'));
      expect(command.description, isNotEmpty);
    });

    test('AddCommand should extend BaseCommand', () {
      final command = AddCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('add'));
      expect(command.description, isNotEmpty);
    });

    test('DiffCommand should extend BaseCommand', () {
      final command = DiffCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('diff'));
      expect(command.description, isNotEmpty);
    });

    test('EditCommand should extend BaseCommand', () {
      final command = EditCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('edit'));
      expect(command.description, isNotEmpty);
    });

    test('FormatCommand should extend BaseCommand', () {
      final command = FormatCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('format'));
      expect(command.description, isNotEmpty);
    });

    test('RollbackCommand should extend BaseCommand', () {
      final command = RollbackCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('rollback'));
      expect(command.description, isNotEmpty);
    });

    test('StatusCommand should extend BaseCommand', () {
      final command = StatusCommand();
      expect(command, isA<BaseCommand>());
      expect(command.name, equals('status'));
      expect(command.description, isNotEmpty);
    });

    test('All commands should have configManager set', () {
      final commands = [
        InitCommand(),
        ApplyCommand(),
        AddCommand(),
        DiffCommand(),
        EditCommand(),
        FormatCommand(),
        RollbackCommand(),
        StatusCommand(),
      ];

      for (final command in commands) {
        command.configManager = configManager;
        expect(command.configManager, equals(configManager));
      }
    });

    test('Commands should have proper argument parsing setup', () {
      final applyCommand = ApplyCommand();
      expect(applyCommand.argParser.options.containsKey('force'), isTrue);
      
      final rollbackCommand = RollbackCommand();
      expect(rollbackCommand.argParser.options.containsKey('count'), isTrue);
      
      final addCommand = AddCommand();
      expect(addCommand.argParser.options.containsKey('file'), isTrue);
    });
  });
}
