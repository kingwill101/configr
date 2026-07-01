import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/strategies/script_strategy.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class CronBlock extends ActionBlock {
  @override
  String get blockType => 'cron';

  String name = '';
  String job = '';
  String minute = '*';
  String hour = '*';
  String day = '*';
  String month = '*';
  String weekday = '*';
  bool disabled = false;
  String user = '';
  String cronFile = '';

  CronBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (job.isNotEmpty) 'job': job,
    if (minute != '*') 'minute': minute,
    if (hour != '*') 'hour': hour,
    if (day != '*') 'day': day,
    if (month != '*') 'month': month,
    if (weekday != '*') 'weekday': weekday,
    if (user.isNotEmpty) 'user': user,
    if (cronFile.isNotEmpty) 'cron_file': cronFile,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (disabled) 'disabled': disabled,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    job = '';
    minute = '*';
    hour = '*';
    day = '*';
    month = '*';
    weekday = '*';
    disabled = false;
    user = '';
    cronFile = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    job = (context.getVariable('job') as String?) ?? '';
    minute = (context.getVariable('minute') as String?) ?? '*';
    hour = (context.getVariable('hour') as String?) ?? '*';
    day = (context.getVariable('day') as String?) ?? '*';
    month = (context.getVariable('month') as String?) ?? '*';
    weekday = (context.getVariable('weekday') as String?) ?? '*';
    disabled = switch (context.getVariable('disabled')) {
      true || 'true' => true,
      _ => false,
    };
    user = (context.getVariable('user') as String?) ?? '';
    cronFile = (context.getVariable('cron_file') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '';
    return '$blockType: $name ($minute $hour $day $month $weekday)';
  }

  @override
  Future<void> execute() async {
    if (name.isEmpty || job.isEmpty) {
      throw ActionFailedException(
        'Name and job are required for cron',
        moduleId: id,
      );
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Managing cron job: $name'));

    OsFacts.detect().requireLinux('cron');

    try {
      final priv = privilegeEscalation;
      final cronLine = disabled
          ? '#$minute $hour $day $month $weekday $job #$name'
          : '$minute $hour $day $month $weekday $job #$name';
      final targetUser = user.isNotEmpty ? user : 'root';

      if (cronFile.isNotEmpty) {
        final file = fileSystem.file(cronFile);
        if (status == 'absent') {
          if (await file.exists()) {
            final lines = await file.readAsLines();
            lines.removeWhere((l) => l.contains(job) && l.endsWith('#$name'));
            await file.writeAsString('${lines.join('\n')}\n');
          }
        } else {
          if (!await file.exists()) {
            await file.create(recursive: true);
          }
          final lines = await file.readAsLines();
          final existingIndex = lines.indexWhere((l) => l.endsWith('#$name'));
          if (existingIndex >= 0) {
            lines[existingIndex] = cronLine;
          } else {
            lines.add(cronLine);
          }
          await file.writeAsString('${lines.join('\n')}\n');
        }
      } else {
        final sh = ScriptStrategy.forPlatform('linux');
        final (exe, args) = sh.runScript(
          'crontab -u $targetUser -l 2>/dev/null',
        );
        final currentCron = await priv.runWithElevatedPrivileges(exe, args);
        final lines = (currentCron.stdout as String)
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();

        if (status == 'absent') {
          lines.removeWhere((l) => l.endsWith('#$name'));
        } else {
          final existingIndex = lines.indexWhere((l) => l.endsWith('#$name'));
          if (existingIndex >= 0) {
            lines[existingIndex] = cronLine;
          } else {
            lines.add(cronLine);
          }
        }

        final newCron = lines.join('\n');
        final strategy = ScriptStrategy.forPlatform('linux');
        final (runExe, shArgs) = strategy.runScript(
          r'echo "$1" | crontab -u "$2" -',
        );
        final result = await priv.runWithElevatedPrivileges(runExe, [
          ...shArgs,
          '_',
          newCron,
          targetUser,
        ]);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to update crontab: ${result.stderr}',
            moduleId: id,
          );
        }
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Cron job $name ${status == 'absent' ? 'removed' : 'added'}',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('cron failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    // No automatic rollback for cron
  }
}
