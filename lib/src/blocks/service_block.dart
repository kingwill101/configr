import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages services across init systems.
///
/// ```i3
/// service {
///   name = "nginx"
///   state = "started"    # started | stopped | restarted | reloaded
///   enabled = true
///   use = "auto"         # auto | systemd | sysvinit | service | launchctl
/// }
/// ```
abstract class ServiceBlock extends ActionBlock {
  @override
  String get blockType => 'service';

  String name = '';
  String state = '';
  bool enabled = false;
  String use = 'auto';

  /// Factory: returns the right platform subclass.
  factory ServiceBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxServiceBlock();
      case OperatingSystem.macos:
        return _MacOSServiceBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDServiceBlock();
      default:
        throw UnsupportedError(
          'Service management not supported on ${Platform.operatingSystem}. '
          'Currently supported: Linux, macOS, FreeBSD.',
        );
    }
  }

  ServiceBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (state.isNotEmpty) 'state': state,
    if (use != 'auto') 'use': use,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (enabled) 'enabled': enabled,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    state = '';
    enabled = false;
    use = 'auto';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    state = (context.getVariable('state') as String?) ?? '';
    enabled = switch (context.getVariable('enabled')) {
      true || 'true' => true,
      _ => false,
    };
    use = (context.getVariable('use') as String?) ?? 'auto';
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '';
    final parts = <String>[name];
    if (state.isNotEmpty) parts.add('state=$state');
    if (enabled) parts.add('enabled');
    return '$blockType: ${parts.join(', ')}';
  }

  /// Run a service command using the given init tool.
  Future<ProcessResult> _runInitCommand(String command, List<String> args) {
    return privilegeEscalation.runWithElevatedPrivileges(
      command,
      args,
      runInShell: true,
    );
  }

  Future<void> _handleState() async {
    switch (state) {
      case 'started':
        await _start();
      case 'stopped':
        await _stop();
      case 'restarted':
        await _restart();
      case 'reloaded':
        await _reload();
      case '':
        break;
      default:
        throw ActionFailedException(
          'Unknown service state: $state. '
          'Expected: started, stopped, restarted, reloaded',
          moduleId: id,
        );
    }
  }

  Future<void> _handleEnabled() async {
    if (!enabled) return;
    await _enable();
  }

  Future<void> _start();
  Future<void> _stop();
  Future<void> _restart();
  Future<void> _reload();
  Future<void> _enable();
}

// ---------------------------------------------------------------------------
// Linux — systemctl > service
// ---------------------------------------------------------------------------

class _LinuxServiceBlock extends ServiceBlock {
  _LinuxServiceBlock() : super._();

  Future<bool> _isSystemd() async {
    try {
      final result = await executionService.run('systemctl', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<ProcessResult> _systemctl(String action) {
    return _runInitCommand('systemctl', [action, name]);
  }

  Future<ProcessResult> _serviceCmd(String action) {
    return _runInitCommand('service', [name, action]);
  }

  Future<ProcessResult> _runAction(String action) async {
    if (use == 'systemd' || (use == 'auto' && await _isSystemd())) {
      return _systemctl(action);
    }
    return _serviceCmd(action);
  }

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Service name is required', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Managing service: $name'));

    try {
      await _handleState();
      await _handleEnabled();

      emitEvent(CompletedEvent(moduleId: id, message: 'Service $name managed'));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('Service failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    if (name.isEmpty) return;
    try {
      if (state == 'started') {
        await _runAction('stop');
      } else if (state == 'stopped') {
        await _runAction('start');
      }
    } catch (_) {}
  }

  @override
  Future<void> _start() async {
    final result = await _runAction('start');
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to start service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _stop() async {
    final result = await _runAction('stop');
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to stop service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _restart() async {
    final result = await _runAction('restart');
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to restart service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _reload() async {
    final result = await _runAction('reload');
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to reload service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _enable() async {
    if (use == 'systemd' || (use == 'auto' && await _isSystemd())) {
      final result = await _systemctl('enable');
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Failed to enable service $name: ${result.stderr}',
          moduleId: id,
        );
      }
    } else {
      try {
        final result = await _runInitCommand('update-rc.d', [name, 'enable']);
        if (result.exitCode != 0) {
          throw Exception();
        }
      } catch (_) {
        final result = await _runInitCommand('chkconfig', [name, 'on']);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to enable service $name: ${result.stderr}',
            moduleId: id,
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// macOS — launchctl
// ---------------------------------------------------------------------------

class _MacOSServiceBlock extends ServiceBlock {
  _MacOSServiceBlock() : super._();

  String? _plistPath;

  Future<String?> _findPlist() async {
    try {
      final result = await executionService.run('find', [
        '/Library/LaunchDaemons',
        '-name',
        '$name.plist',
      ]);
      if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
        return (result.stdout as String).trim().split('\n').first;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Service name is required', moduleId: id);
    }

    _plistPath ??= await _findPlist();

    emitEvent(StartedEvent(moduleId: id, message: 'Managing service: $name'));

    try {
      await _handleState();
      await _handleEnabled();

      emitEvent(CompletedEvent(moduleId: id, message: 'Service $name managed'));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('Service failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    if (name.isEmpty) return;
    try {
      if (state == 'started') {
        await _runInitCommand('launchctl', ['unload', _plistPath ?? name]);
      } else if (state == 'stopped') {
        await _runInitCommand('launchctl', ['load', _plistPath ?? name]);
      }
    } catch (_) {}
  }

  @override
  Future<void> _start() async {
    if (_plistPath == null) {
      throw ActionFailedException(
        'Could not find plist for service $name',
        moduleId: id,
      );
    }
    final result = await _runInitCommand('launchctl', [
      'load',
      '-w',
      _plistPath!,
    ]);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to start service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _stop() async {
    if (_plistPath == null) {
      throw ActionFailedException(
        'Could not find plist for service $name',
        moduleId: id,
      );
    }
    final result = await _runInitCommand('launchctl', [
      'unload',
      '-w',
      _plistPath!,
    ]);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to stop service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _restart() async {
    await _stop();
    await _start();
  }

  @override
  Future<void> _reload() async {
    await _restart();
  }

  @override
  Future<void> _enable() async {
    _plistPath ??= await _findPlist();
    if (_plistPath != null) {
      await _runInitCommand('launchctl', ['load', '-w', _plistPath!]);
    }
  }
}

// ---------------------------------------------------------------------------
// FreeBSD — service command
// ---------------------------------------------------------------------------

class _FreeBSDServiceBlock extends ServiceBlock {
  _FreeBSDServiceBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Service name is required', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Managing service: $name'));

    try {
      await _handleState();
      await _handleEnabled();

      emitEvent(CompletedEvent(moduleId: id, message: 'Service $name managed'));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('Service failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    if (name.isEmpty) return;
    try {
      if (state == 'started') {
        await _runInitCommand('service', [name, 'stop']);
      } else if (state == 'stopped') {
        await _runInitCommand('service', [name, 'start']);
      }
    } catch (_) {}
  }

  @override
  Future<void> _start() async {
    final result = await _runInitCommand('service', [name, 'start']);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to start service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _stop() async {
    final result = await _runInitCommand('service', [name, 'stop']);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to stop service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _restart() async {
    final result = await _runInitCommand('service', [name, 'restart']);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to restart service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _reload() async {
    final result = await _runInitCommand('service', [name, 'reload']);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to reload service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> _enable() async {
    final result = await _runInitCommand('sysrc', ['${name}_enable=YES']);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to enable service $name: ${result.stderr}',
        moduleId: id,
      );
    }
  }
}
