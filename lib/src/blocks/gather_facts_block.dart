import 'dart:io' show Platform;

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class GatherFactsBlock extends ActionBlock {
  @override
  String get blockType => 'gather_facts';

  String gatherSubset = 'all';

  GatherFactsBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (gatherSubset != 'all') 'gather_subset': gatherSubset,
  };

  @override
  void resetState() {
    super.resetState();
    gatherSubset = 'all';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    gatherSubset =
        (context.getVariable('gather_subset') as String?) ?? 'all';
  }

  @override
  String dryRunSummary() => '$blockType: subset=$gatherSubset';

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Gathering facts'));

try {
      // ---- OS facts from OsFacts.detect() ----
      final facts = OsFacts.detect();

      context.setVariable('os_family', facts.family.name);
      context.setVariable('distribution', facts.distribution);
      context.setVariable(
        'distribution_version',
        facts.distributionVersion,
      );
      context.setVariable('architecture', facts.architecture);
      context.setVariable('system', facts.os.name);
      context.setVariable('hostname', Platform.localHostname);

      // ---- Kernel information via uname ----
      try {
        final unameResult = await runCommand(
          'uname',
          ['-a'],
          checkExitCode: false,
        );
        if (unameResult.exitCode == 0) {
          context.setVariable(
            'kernel',
            (unameResult.stdout as String).trim(),
          );
        }
      } catch (_) {}

      try {
        final kernelResult = await runCommand(
          'uname',
          ['-r'],
          checkExitCode: false,
        );
        if (kernelResult.exitCode == 0) {
          context.setVariable(
            'kernel_version',
            (kernelResult.stdout as String).trim(),
          );
        }
      } catch (_) {}

      // ---- CPU count via nproc ----
      try {
        final nprocResult = await runCommand(
          'nproc',
          [],
          checkExitCode: false,
        );
        if (nprocResult.exitCode == 0) {
          context.setVariable(
            'processor_count',
            (nprocResult.stdout as String).trim(),
          );
        }
      } catch (_) {}

      // ---- Memory info (OS-specific) ----
      if (facts.isLinux) {
        try {
          final memResult = await runCommand(
            'free',
            ['-b'],
            checkExitCode: false,
          );
          if (memResult.exitCode == 0) {
            final lines = (memResult.stdout as String).split('\n');
            if (lines.length > 1) {
              final parts = lines[1].split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                final totalBytes = int.tryParse(parts[1]) ?? 0;
                context.setVariable(
                  'memtotal_mb',
                  (totalBytes ~/ (1024 * 1024)).toString(),
                );
              }
            }
          }
        } catch (_) {}
      } else if (facts.isMacOS) {
        try {
          final memResult = await runCommand(
            'sysctl',
            ['hw.memsize'],
            checkExitCode: false,
          );
          if (memResult.exitCode == 0) {
            final output = (memResult.stdout as String).trim();
            final parts = output.split(':');
            if (parts.length >= 2) {
              final totalBytes = int.tryParse(parts[1].trim()) ?? 0;
              context.setVariable(
                'memtotal_mb',
                (totalBytes ~/ (1024 * 1024)).toString(),
              );
            }
          }
        } catch (_) {}
      } else if (facts.os == OperatingSystem.freebsd) {
        try {
          final memResult = await runCommand(
            'sysctl',
            ['hw.physmem'],
            checkExitCode: false,
          );
          if (memResult.exitCode == 0) {
            final output = (memResult.stdout as String).trim();
            final parts = output.split(':');
            if (parts.length >= 2) {
              final totalBytes = int.tryParse(parts[1].trim()) ?? 0;
              context.setVariable(
                'memtotal_mb',
                (totalBytes ~/ (1024 * 1024)).toString(),
              );
            }
          }
        } catch (_) {}
      }

      // ---- Disk info ----
      try {
        final dfResult = await runCommand(
          'df',
          ['-B1', '/'],
          checkExitCode: false,
        );
        if (dfResult.exitCode == 0) {
          context.setVariable(
            'mounts',
            (dfResult.stdout as String).trim(),
          );
        }
      } catch (_) {}

      // ---- Network interfaces (OS-specific) ----
      if (facts.isLinux) {
        try {
          final netResult = await runCommand(
            'ip',
            ['-o', 'addr', 'show'],
            checkExitCode: false,
          );
          if (netResult.exitCode == 0) {
            context.setVariable(
              'interfaces',
              (netResult.stdout as String).trim(),
            );
          }
        } catch (_) {}
      } else {
        try {
          final netResult = await runCommand(
            'ifconfig',
            [],
            checkExitCode: false,
          );
          if (netResult.exitCode == 0) {
            context.setVariable(
              'interfaces',
              (netResult.stdout as String).trim(),
            );
          }
        } catch (_) {}
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Facts gathered'),
      );
      status = 'completed';
    } catch (e) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Failed to gather facts: $e'),
      );
      status = 'completed';
    }
  }

  @override
  Future<void> rollback() async {}
}
