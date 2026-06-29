import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages groups.
abstract class GroupBlock extends ActionBlock {
  @override
  String get blockType => 'group';

  String name = '';
  String gid = '';
  bool system = false;
  bool local = false;
  bool force = false;

  factory GroupBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxGroupBlock();
      case OperatingSystem.macos:
        return _MacOSGroupBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDGroupBlock();
      default:
        throw UnsupportedError(
          'Group management not supported on ${Platform.operatingSystem}. '
          'Currently supported: Linux.',
        );
    }
  }

  GroupBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (gid.isNotEmpty) 'gid': gid,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (system) 'system': system,
    if (local) 'local': local,
    if (force) 'force': force,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    gid = '';
    system = false;
    local = false;
    force = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    gid = (context.getVariable('gid') as String?) ?? '';
    system = switch (context.getVariable('system')) {
      true || 'true' => true,
      _ => false,
    };
    local = switch (context.getVariable('local')) {
      true || 'true' => true,
      _ => false,
    };
    force = switch (context.getVariable('force')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '';
    final action = status == 'absent' ? 'remove' : 'manage';
    return '$blockType: $name ($action)';
  }
}

// ---------------------------------------------------------------------------
// Linux — groupadd / groupmod / groupdel / getent
// ---------------------------------------------------------------------------

class _LinuxGroupBlock extends GroupBlock {
  _LinuxGroupBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Name is required for group', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Managing group: $name'));

    try {
      if (status == 'absent') {
        await _removeGroup();
      } else {
        await _createOrUpdateGroup();
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Group $name ${status == 'absent' ? 'removed' : 'managed'}',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('group failed: $e', moduleId: id);
    }
  }

  Future<void> _createOrUpdateGroup() async {
    final priv = privilegeEscalation;
    final groupExists = await _groupExists();

    if (groupExists) {
      if (gid.isNotEmpty) {
        final result = await priv.runWithElevatedPrivileges('groupmod', [
          '-g',
          gid,
          name,
        ]);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Failed to modify group: ${result.stderr}',
            moduleId: id,
          );
        }
      }
    } else {
      final args = <String>[];
      if (gid.isNotEmpty) args.addAll(['-g', gid]);
      if (system) args.add('-r');
      if (force) args.add('-f');
      args.add(name);

      final result = await priv.runWithElevatedPrivileges('groupadd', args);
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Failed to create group: ${result.stderr}',
          moduleId: id,
        );
      }
    }
  }

  Future<void> _removeGroup() async {
    final priv = privilegeEscalation;
    final result = await priv.runWithElevatedPrivileges('groupdel', [name]);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to remove group: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  Future<bool> _groupExists() async {
    final priv = privilegeEscalation;
    final result = await priv.runWithElevatedPrivileges('getent', [
      'group',
      name,
    ]);
    return result.exitCode == 0;
  }

  @override
  Future<void> rollback() async {
    if (name.isEmpty) return;
    await privilegeEscalation.runWithElevatedPrivileges('groupdel', [name]);
  }
}

// ---------------------------------------------------------------------------
// macOS stub
// ---------------------------------------------------------------------------

class _MacOSGroupBlock extends GroupBlock {
  _MacOSGroupBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Group management on macOS is not yet implemented. '
      'Use dseditgroup / dscl manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// FreeBSD stub
// ---------------------------------------------------------------------------

class _FreeBSDGroupBlock extends GroupBlock {
  _FreeBSDGroupBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Group management on FreeBSD is not yet implemented. '
      'Use pw groupadd/groupmod/groupdel manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}
