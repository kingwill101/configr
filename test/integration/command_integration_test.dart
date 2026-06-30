@Tags(['integration'])
library;

// CLI commands are in cli/commands/ - using relative imports
import 'package:configr/src/cli/commands/add.dart';
import 'package:configr/src/cli/commands/apply.dart';
import 'package:configr/src/cli/commands/base_command.dart';
import 'package:configr/src/cli/commands/diff.dart';
import 'package:configr/src/cli/commands/edit.dart';
import 'package:configr/src/cli/commands/format.dart';
import 'package:configr/src/cli/commands/init.dart';
import 'package:configr/src/cli/commands/rollback.dart';
import 'package:configr/src/cli/commands/status.dart';
import 'package:configr/configr.dart';
import 'package:test/test.dart';

void main() {
  group('Command Integration Tests', () {
    late ConfigrRuntime runtime;

    setUp(() {
      runtime = ConfigrRuntime(
        ConfigrConfig(privilegeEscalation: NoPrivilegeEscalation()),
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

    test('All commands should have runtime set', () {
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
        command.runtime = runtime;
        expect(command.runtime, equals(runtime));
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
