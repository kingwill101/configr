import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages user accounts.
///
/// Base class holds platform-agnostic property parsing. Platform-specific
/// subclasses override [execute] with OS-native commands:
///
/// | Subclass | platform | OS | Commands |
/// |---|---|---|---|
/// | [_LinuxUserBlock] | `Linux` | Linux | `useradd`/`usermod`/`userdel` |
/// | [_MacOSUserBlock] | `Darwin` | macOS | *(planned)* |
/// | [_FreeBSDUserBlock] | `FreeBSD` | FreeBSD | *(planned)* |
abstract class UserBlock extends ActionBlock {
  @override
  String get blockType => 'user';

  String name = '';
  String uid = '';
  String group = '';
  String groups = '';
  String comment = '';
  String home = '';
  String shell = '';
  String password = '';
  bool system = false;
  bool createHome = true;
  bool moveHome = false;
  bool remove = false;
  bool force = false;
  bool append = false;

  /// Factory: returns the right platform subclass.
  factory UserBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxUserBlock();
      case OperatingSystem.macos:
        return _MacOSUserBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDUserBlock();
      default:
        throw UnsupportedError(
          'User management not supported on ${Platform.operatingSystem}. '
          'Currently supported: Linux.',
        );
    }
  }

  /// Protected constructor for subclasses.
  UserBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (uid.isNotEmpty) 'uid': uid,
    if (group.isNotEmpty) 'group': group,
    if (groups.isNotEmpty) 'groups': groups,
    if (comment.isNotEmpty) 'comment': comment,
    if (home.isNotEmpty) 'home': home,
    if (shell.isNotEmpty) 'shell': shell,
    if (password.isNotEmpty) 'password': password,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (system) 'system': system,
    if (!createHome) 'create_home': createHome,
    if (moveHome) 'move_home': moveHome,
    if (remove) 'remove': remove,
    if (force) 'force': force,
    if (append) 'append': append,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    uid = '';
    group = '';
    groups = '';
    comment = '';
    home = '';
    shell = '';
    password = '';
    system = false;
    createHome = true;
    moveHome = false;
    remove = false;
    force = false;
    append = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    uid = (context.getVariable('uid') as String?) ?? '';
    group = (context.getVariable('group') as String?) ?? '';
    groups = (context.getVariable('groups') as String?) ?? '';
    comment = (context.getVariable('comment') as String?) ?? '';
    home = (context.getVariable('home') as String?) ?? '';
    shell = (context.getVariable('shell') as String?) ?? '';
    password = (context.getVariable('password') as String?) ?? '';
    system = switch (context.getVariable('system')) {
      true || 'true' => true,
      _ => false,
    };
    createHome = switch (context.getVariable('create_home')) {
      false || 'false' => false,
      _ => true,
    };
    moveHome = switch (context.getVariable('move_home')) {
      true || 'true' => true,
      _ => false,
    };
    remove = switch (context.getVariable('remove')) {
      true || 'true' => true,
      _ => false,
    };
    force = switch (context.getVariable('force')) {
      true || 'true' => true,
      _ => false,
    };
    append = switch (context.getVariable('append')) {
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
// Linux — useradd / usermod / userdel / chpasswd
// ---------------------------------------------------------------------------

class _LinuxUserBlock extends UserBlock {
  _LinuxUserBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Name is required for user', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Managing user: $name'));

    try {
      if (status == 'absent') {
        await _removeUser();
      } else {
        await _createOrUpdateUser();
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'User $name ${status == 'absent' ? 'removed' : 'managed'}',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('user failed: $e', moduleId: id);
    }
  }

  Future<void> _createOrUpdateUser() async {
    final priv = privilegeEscalation;
    final userExists = await _userExists();

    if (userExists) {
      final args = <String>[];
      if (uid.isNotEmpty) args.addAll(['-u', uid]);
      if (group.isNotEmpty) args.addAll(['-g', group]);
      if (groups.isNotEmpty) {
        args.addAll(append ? ['-aG', groups] : ['-G', groups]);
      }
      if (comment.isNotEmpty) args.addAll(['-c', comment]);
      if (home.isNotEmpty) {
        args.addAll(['-d', home]);
        if (moveHome) args.add('-m');
      }
      if (shell.isNotEmpty) args.addAll(['-s', shell]);
      args.add(name);

      final result = await priv.runWithElevatedPrivileges('usermod', args);
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Failed to modify user: ${result.stderr}', moduleId: id,
        );
      }
    } else {
      final args = <String>[];
      if (uid.isNotEmpty) args.addAll(['-u', uid]);
      if (group.isNotEmpty) args.addAll(['-g', group]);
      if (groups.isNotEmpty) args.addAll(['-G', groups]);
      if (comment.isNotEmpty) args.addAll(['-c', comment]);
      if (home.isNotEmpty) {
        args.addAll(['-d', home]);
      } else if (createHome) {
        args.add('-m');
      }
      if (shell.isNotEmpty) args.addAll(['-s', shell]);
      if (system) args.add('-r');
      args.add(name);

      final result = await priv.runWithElevatedPrivileges('useradd', args);
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Failed to create user: ${result.stderr}', moduleId: id,
        );
      }
    }

    if (password.isNotEmpty) {
      final chpasswd = await priv.runWithElevatedPrivileges(
        'sh', ['-c', 'echo "$name:$password" | chpasswd'],
      );
      if (chpasswd.exitCode != 0) {
        throw ActionFailedException(
          'Failed to set password: ${chpasswd.stderr}', moduleId: id,
        );
      }
    }
  }

  Future<void> _removeUser() async {
    final priv = privilegeEscalation;
    final args = <String>[];
    if (force) args.add('-f');
    if (remove) args.add('-r');
    args.add(name);

    final result = await priv.runWithElevatedPrivileges('userdel', args);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to remove user: ${result.stderr}', moduleId: id,
      );
    }
  }

  Future<bool> _userExists() async {
    final priv = privilegeEscalation;
    final result = await priv.runWithElevatedPrivileges('id', [name]);
    return result.exitCode == 0;
  }

  @override
  Future<void> rollback() async {
    if (name.isEmpty) return;
    await privilegeEscalation.runWithElevatedPrivileges('userdel', ['-r', name]);
  }
}

// ---------------------------------------------------------------------------
// macOS stub
// ---------------------------------------------------------------------------

class _MacOSUserBlock extends UserBlock {
  _MacOSUserBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'User management on macOS is not yet implemented. '
      'Use dscl / sysadminctl manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// FreeBSD stub
// ---------------------------------------------------------------------------

class _FreeBSDUserBlock extends UserBlock {
  _FreeBSDUserBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'User management on FreeBSD is not yet implemented. '
      'Use pw useradd/usermod/userdel manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}
