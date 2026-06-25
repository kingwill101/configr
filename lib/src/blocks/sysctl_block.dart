import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages kernel parameters via sysctl.
///
/// Supports state=absent and value assignment.
/// ignoreerrors, sysctl_set, reload, and FreeBSD/OpenBSD specifics.
abstract class SysctlBlock extends ActionBlock {
  @override
  String get blockType => 'sysctl';

  String name = '';
  String value = '';
  bool reload = true;
  bool ignoreErrors = false;
  String sysctlFile = '';
  bool sysctlSet = false;

  factory SysctlBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxSysctlBlock();
      case OperatingSystem.macos:
        return _MacOSSysctlBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDSysctlBlock();
      case OperatingSystem.openbsd:
        return _OpenBSDSysctlBlock();
      default:
        return _UnsupportedSysctlBlock(facts);
    }
  }

  SysctlBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (value.isNotEmpty) 'value': value,
    if (sysctlFile.isNotEmpty) 'sysctl_file': sysctlFile,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!reload) 'reload': reload,
    if (ignoreErrors) 'ignore_errors': ignoreErrors,
    if (sysctlSet) 'sysctl_set': sysctlSet,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    value = '';
    reload = true;
    ignoreErrors = false;
    sysctlFile = '';
    sysctlSet = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    value = (context.getVariable('value') as String?) ?? '';
    reload = switch (context.getVariable('reload')) {
      false || 'false' => false,
      _ => true,
    };
    ignoreErrors = switch (context.getVariable('ignore_errors')) {
      true || 'true' => true,
      _ => false,
    };
    sysctlFile = (context.getVariable('sysctl_file') as String?) ?? '';
    sysctlSet = switch (context.getVariable('sysctl_set')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  String dryRunSummary() {
    if (name.isNotEmpty && value.isNotEmpty) {
      return '$blockType: $name=$value';
    }
    return '';
  }
}

// ---------------------------------------------------------------------------
// Linux — sysctl -w + /etc/sysctl.conf management
// ---------------------------------------------------------------------------

class _LinuxSysctlBlock extends SysctlBlock {
  _LinuxSysctlBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Name is required for sysctl', moduleId: id);
    }

    emitEvent(StartedEvent(
      moduleId: id, message: 'Managing sysctl: $name',
    ));

    try {
      final priv = privilegeEscalation;
      final sysctlFile = this.sysctlFile.isNotEmpty
          ? this.sysctlFile
          : '/etc/sysctl.conf';

      final currentFile = await _getFileValue(sysctlFile);

      bool changed = false;
      bool needsReload = false;

      if (status == 'absent') {
        // Remove from file
        if (currentFile != null) {
          await _removeFromFile(sysctlFile);
          changed = true;
          needsReload = true;
        }
      } else {
        // present — ensure value in file
        if (currentFile == null || currentFile != value) {
          await _writeToFile(sysctlFile);
          changed = true;
          needsReload = true;
        }
      }

      // sysctl_set: also set via sysctl -w now
      if (sysctlSet && status != 'absent') {
        final setResult = await _sysctlSet(priv);
        if (setResult) changed = true;
      }

      // reload if needed
      if (needsReload && reload) {
        await _sysctlReload(priv, sysctlFile);
      }

      if (changed) {
        emitEvent(CompletedEvent(
          moduleId: id, message: 'Sysctl $name ${status == 'absent' ? 'removed' : 'set to $value'}',
        ));
        status = 'completed';
      } else {
        emitEvent(StatusUpdateEvent(
          moduleId: id, message: 'Sysctl $name already at desired state',
          level: StatusEvent.info,
        ));
      }
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('sysctl failed: $e', moduleId: id);
    }
  }

  Future<String?> _getFileValue(String file) async {
    final sysctlFile = fileSystem.file(file);
    if (!await sysctlFile.exists()) return null;
    final lines = await sysctlFile.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
      if (!trimmed.contains('=')) continue;
      final eq = trimmed.indexOf('=');
      final key = trimmed.substring(0, eq).trim();
      if (key == name) return trimmed.substring(eq + 1).trim();
    }
    return null;
  }

  Future<void> _writeToFile(String file) async {
    final sysctlFile = fileSystem.file(file);
    List<String> lines = [];
    bool found = false;

    if (await sysctlFile.exists()) {
      lines = await sysctlFile.readAsLines();
      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
        if (!trimmed.contains('=')) continue;
        final eq = trimmed.indexOf('=');
        final key = trimmed.substring(0, eq).trim();
        if (key == name) {
          lines[i] = '$name=$value';
          found = true;
          break;
        }
      }
    }

    if (!found) lines.add('$name=$value');
    await sysctlFile.writeAsString('${lines.join('\n')}\n');
  }

  Future<void> _removeFromFile(String file) async {
    final sysctlFile = fileSystem.file(file);
    if (!await sysctlFile.exists()) return;

    final lines = await sysctlFile.readAsLines();
    lines.removeWhere((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) return false;
      if (!trimmed.contains('=')) return false;
      final eq = trimmed.indexOf('=');
      return trimmed.substring(0, eq).trim() == name;
    });
    await sysctlFile.writeAsString('${lines.join('\n')}\n');
  }

  Future<bool> _sysctlSet(dynamic priv) async {
    // Read current value first — avoids spurious "permission denied" errors
    // when running inside containers where the value is already correct.
    final current = await priv.runWithElevatedPrivileges(
      'sysctl', ['-n', name],
    );
    if (current.exitCode == 0) {
      final curVal = (current.stdout is String
          ? current.stdout as String
          : String.fromCharCodes(current.stdout as List<int>))
          .trim();
      if (curVal == value) return false; // already correct
    }

    final result = await priv.runWithElevatedPrivileges(
      'sysctl', ['-w', '$name=$value'],
    );
    if (result.exitCode != 0 && !ignoreErrors) {
      throw ActionFailedException(
        'sysctl -w failed: ${result.stderr}', moduleId: id,
      );
    }
    return result.exitCode == 0;
  }

  Future<void> _sysctlReload(dynamic priv, String file) async {
    final result = await priv.runWithElevatedPrivileges(
      'sysctl', ['-p', file],
    );
    if (result.exitCode != 0 && !ignoreErrors) {
      throw ActionFailedException(
        'sysctl -p failed: ${result.stderr}', moduleId: id,
      );
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// macOS  (sysctl name=value — no -w flag)
// ---------------------------------------------------------------------------

class _MacOSSysctlBlock extends SysctlBlock {
  _MacOSSysctlBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Sysctl on macOS is not yet implemented. '
      'Use sysctl name=value (no -w flag on macOS).',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// FreeBSD  (sysctl name=value - no -w, reload via /etc/rc.d/sysctl)
// ---------------------------------------------------------------------------

class _FreeBSDSysctlBlock extends SysctlBlock {
  _FreeBSDSysctlBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Name is required for sysctl', moduleId: id);
    }

    // FreeBSD only supports reloading /etc/sysctl.conf or /etc/sysctl.conf.local
    final sysctlFile = this.sysctlFile.isNotEmpty
        ? this.sysctlFile
        : '/etc/sysctl.conf';
    final allowedFiles = ['/etc/sysctl.conf', '/etc/sysctl.conf.local'];

    if (reload && !allowedFiles.contains(sysctlFile)) {
      throw ActionFailedException(
        '$sysctlFile cannot be reloaded on FreeBSD. Set reload=false.',
        moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id, message: 'Managing sysctl on FreeBSD: $name',
    ));

    try {
      final priv = privilegeEscalation;

      // FreeBSD: sysctl name=value (no -w flag)
      if (status != 'absent' && value.isNotEmpty) {
        final result = await priv.runWithElevatedPrivileges(
          'sysctl', ['$name=$value'],
        );
        if (result.exitCode != 0 && !ignoreErrors) {
          throw ActionFailedException(
            'sysctl failed on FreeBSD: ${result.stderr}', moduleId: id,
          );
        }
      }

      // Manage file
      if (status == 'absent') {
        await _removeFromFile(sysctlFile);
      } else {
        await _writeToFile(sysctlFile);
      }

      // Reload via rc.d script
      if (reload) {
        final reloadResult = await priv.runWithElevatedPrivileges(
          '/etc/rc.d/sysctl', ['reload'],
        );
        if (reloadResult.exitCode != 0 && !ignoreErrors) {
          throw ActionFailedException(
            'sysctl reload failed: ${reloadResult.stderr}', moduleId: id,
          );
        }
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Sysctl $name ${status == 'absent' ? 'removed' : 'set to $value'} on FreeBSD',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('sysctl failed on FreeBSD: $e', moduleId: id);
    }
  }

  Future<void> _writeToFile(String file) async {
    final sysctlFile = fileSystem.file(file);
    List<String> lines = [];
    bool found = false;

    if (await sysctlFile.exists()) {
      lines = await sysctlFile.readAsLines();
      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
        if (!trimmed.contains('=')) continue;
        final eq = trimmed.indexOf('=');
        final key = trimmed.substring(0, eq).trim();
        if (key == name) {
          lines[i] = '$name=$value';
          found = true;
          break;
        }
      }
    }
    if (!found) lines.add('$name=$value');
    await sysctlFile.writeAsString('${lines.join('\n')}\n');
  }

  Future<void> _removeFromFile(String file) async {
    final sysctlFile = fileSystem.file(file);
    if (!await sysctlFile.exists()) return;
    final lines = await sysctlFile.readAsLines();
    lines.removeWhere((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';')) return false;
      if (!trimmed.contains('=')) return false;
      final eq = trimmed.indexOf('=');
      return trimmed.substring(0, eq).trim() == name;
    });
    await sysctlFile.writeAsString('${lines.join('\n')}\n');
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// OpenBSD  (sysctl name=value — no -w/-e, no -p reload)
// ---------------------------------------------------------------------------

class _OpenBSDSysctlBlock extends SysctlBlock {
  _OpenBSDSysctlBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException('Name is required for sysctl', moduleId: id);
    }

    emitEvent(StartedEvent(
      moduleId: id, message: 'Managing sysctl on OpenBSD: $name',
    ));

    try {
      final priv = privilegeEscalation;

      // OpenBSD: sysctl name=value (no -w, no -e, no -p)
      if (value.isNotEmpty && status != 'absent') {
        final result = await priv.runWithElevatedPrivileges(
          'sysctl', ['$name=$value'],
        );
        if (result.exitCode != 0 && !ignoreErrors) {
          throw ActionFailedException(
            'sysctl failed on OpenBSD: ${result.stderr}', moduleId: id,
          );
        }
      }

      // OpenBSD doesn't have sysctl -p, so set each value individually
      if (reload && status != 'absent') {
        final result = await priv.runWithElevatedPrivileges(
          'sysctl', ['$name=$value'],
        );
        if (result.exitCode != 0 && !ignoreErrors) {
          throw ActionFailedException(
            'sysctl reload failed on OpenBSD: ${result.stderr}', moduleId: id,
          );
        }
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Sysctl $name set to $value on OpenBSD',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('sysctl failed on OpenBSD: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Unsupported OS placeholder
// ---------------------------------------------------------------------------

class _UnsupportedSysctlBlock extends SysctlBlock {
  _UnsupportedSysctlBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Sysctl is not supported on ${_facts.os.name}. '
      'Currently supported: Linux.',
    );
  }

  @override
  Future<void> rollback() async {}
}
