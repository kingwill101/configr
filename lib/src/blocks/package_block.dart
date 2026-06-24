import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class PackageBlock extends ActionBlock {
  @override
  String get blockType => 'package';

  String name = '';
  String state = 'present';
  String use = 'auto';

  PackageBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (state != 'present') 'state': state,
    if (use != 'auto') 'use': use,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    state = 'present';
    use = 'auto';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    state = (context.getVariable('state') as String?) ?? 'present';
    use = (context.getVariable('use') as String?) ?? 'auto';
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '$blockType: (empty)';
    return '$blockType: $name ($state)';
  }

  Future<String> _detectPackageManager() async {
    if (use != 'auto') return use;
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        if (await _commandExists('apt-get')) return 'apt';
        if (await _commandExists('dnf')) return 'dnf';
        if (await _commandExists('yum')) return 'yum';
        if (await _commandExists('pacman')) return 'pacman';
        if (await _commandExists('zypper')) return 'zypper';
        return 'apt';
      case OperatingSystem.macos:
        return 'brew';
      case OperatingSystem.freebsd:
        return 'pkg';
      default:
        return 'apt';
    }
  }

  Future<bool> _commandExists(String cmd) async {
    const paths = [
      '/usr/bin',
      '/usr/local/bin',
      '/opt/homebrew/bin',
      '/bin',
      '/opt/bin',
    ];
    for (final p in paths) {
      if (await FileUtils.fileExists('$p/$cmd')) return true;
    }
    return false;
  }

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('name is required for package', moduleId: id);
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Managing package: $name',
    ));

    try {
      final pm = await _detectPackageManager();

      switch (state) {
        case 'present':
          await _ensurePresent(pm);
        case 'absent':
          await _ensureAbsent(pm);
        case 'latest':
          await _ensureLatest(pm);
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Package $name ($state) via $pm',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('package failed: $e', moduleId: id);
    }
  }

  Future<void> _ensurePresent(String pm) async {
    switch (pm) {
      case 'apt':
        await runCommand('apt-get', ['install', '-y', name], requireElevation: true);
      case 'dnf':
        await runCommand('dnf', ['install', '-y', name], requireElevation: true);
      case 'yum':
        await runCommand('yum', ['install', '-y', name], requireElevation: true);
      case 'pacman':
        await runCommand('pacman', ['--noconfirm', '-S', name], requireElevation: true);
      case 'brew':
        await runCommand('brew', ['install', name]);
      case 'zypper':
        await runCommand('zypper', ['--non-interactive', 'install', name], requireElevation: true);
      case 'pkg':
        await runCommand('pkg', ['install', '-y', name], requireElevation: true);
      default:
        throw ActionFailedException('Unsupported package manager: $pm',
            moduleId: id);
    }
  }

  Future<void> _ensureAbsent(String pm) async {
    switch (pm) {
      case 'apt':
        await runCommand('apt-get', ['remove', '-y', name], requireElevation: true);
      case 'dnf':
        await runCommand('dnf', ['remove', '-y', name], requireElevation: true);
      case 'yum':
        await runCommand('yum', ['remove', '-y', name], requireElevation: true);
      case 'pacman':
        await runCommand('pacman', ['--noconfirm', '-R', name], requireElevation: true);
      case 'brew':
        await runCommand('brew', ['uninstall', name]);
      case 'zypper':
        await runCommand('zypper', ['--non-interactive', 'remove', name], requireElevation: true);
      case 'pkg':
        await runCommand('pkg', ['delete', '-y', name], requireElevation: true);
      default:
        throw ActionFailedException('Unsupported package manager: $pm',
            moduleId: id);
    }
  }

  Future<void> _ensureLatest(String pm) async {
    switch (pm) {
      case 'apt':
        await runCommand('apt-get', ['install', '-y', '--only-upgrade', name], requireElevation: true);
      case 'dnf':
        await runCommand('dnf', ['upgrade', '-y', name], requireElevation: true);
      case 'yum':
        await runCommand('yum', ['upgrade', '-y', name], requireElevation: true);
      case 'pacman':
        await runCommand('pacman', ['--noconfirm', '-Syu', name], requireElevation: true);
      case 'brew':
        await runCommand('brew', ['upgrade', name]);
      case 'zypper':
        await runCommand('zypper', ['--non-interactive', 'update', name], requireElevation: true);
      case 'pkg':
        await runCommand('pkg', ['upgrade', '-y', name], requireElevation: true);
      default:
        throw ActionFailedException('Unsupported package manager: $pm',
            moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
  }
}
