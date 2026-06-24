import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Sets the system hostname — Ansible-style platform subclass dispatch.
///
/// Ansible reference: hostname.py — separates current vs permanent hostname,
/// supports `use` strategy override, and multiple Linux distribution strategies.
abstract class HostnameBlock extends ActionBlock {
  @override
  String get blockType => 'hostname';

  String name = '';
  String use = '';

  /// Ansible-style factory: returns the right platform subclass.
  factory HostnameBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxHostnameBlock();
      case OperatingSystem.macos:
        return _MacOSHostnameBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDHostnameBlock();
      default:
        return _UnsupportedHostnameBlock(facts);
    }
  }

  HostnameBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (use.isNotEmpty) 'use': use,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    use = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    use = (context.getVariable('use') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    return name.isNotEmpty ? '$blockType: $name' : '';
  }
}

// ---------------------------------------------------------------------------
// Linux — hostnamectl (systemd) → /etc/hostname (file) → hostname cmd
// ---------------------------------------------------------------------------

class _LinuxHostnameBlock extends HostnameBlock {
  _LinuxHostnameBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException(
        'Name is required for hostname',
        moduleId: id,
      );
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Setting hostname to: $name'),
    );

    try {
      final priv = privilegeEscalation;
      final strategy = use.toLowerCase();

      if (strategy == 'systemd' || strategy.isEmpty) {
        // Systemd strategy (hostnamectl) — sets both current and permanent
        if (name.length > 64) {
          throw ActionFailedException(
            'Name cannot be longer than 64 characters on systemd hosts',
            moduleId: id,
          );
        }

        // Ansible: update permanent hostname first, then current,
        // to avoid NetworkManager complaints
        final staticResult = await priv.runWithElevatedPrivileges(
          'hostnamectl',
          ['--static', 'set-hostname', name],
        );
        if (staticResult.exitCode != 0) {
          // Fall back to direct /etc/hostname write + hostname command
          await _fileStrategyExec(name, priv);
        } else {
          final transientResult = await priv.runWithElevatedPrivileges(
            'hostnamectl',
            ['--transient', 'set-hostname', name],
          );
          if (transientResult.exitCode != 0) {
            throw ActionFailedException(
              'hostnamectl failed: ${transientResult.stderr}',
              moduleId: id,
            );
          }
        }
      } else if (strategy == 'file' || strategy == 'generic') {
        await _fileStrategyExec(name, priv);
      } else if (strategy == 'hostname') {
        // Plain hostname command (current only)
        final result = await priv.runWithElevatedPrivileges('hostname', [name]);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'hostname command failed: ${result.stderr}',
            moduleId: id,
          );
        }
      } else {
        throw ActionFailedException('Unknown use strategy: $use', moduleId: id);
      }

      emitEvent(CompletedEvent(moduleId: id, message: 'Hostname set to $name'));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('hostname failed: $e', moduleId: id);
    }
  }

  Future<void> _fileStrategyExec(String hostname, dynamic priv) async {
    // Write to /etc/hostname (permanent)
    final etcHostname = fileSystem.file('/etc/hostname');
    await etcHostname.writeAsString('$hostname\n');

    // Set current hostname
    await priv.runWithElevatedPrivileges('hostname', [hostname]);
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// macOS  (scutil --set HostName / ComputerName / LocalHostName)
// ---------------------------------------------------------------------------

class _MacOSHostnameBlock extends HostnameBlock {
  _MacOSHostnameBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Hostname on macOS is not yet implemented. '
      'Use scutil --set HostName manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// FreeBSD  (/etc/rc.conf.d/hostname + hostname cmd)
// ---------------------------------------------------------------------------

class _FreeBSDHostnameBlock extends HostnameBlock {
  _FreeBSDHostnameBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Hostname on FreeBSD is not yet implemented. '
      'Modify /etc/rc.conf.d/hostname and run hostname manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Unsupported OS placeholder — throws on execute, not construction
// ---------------------------------------------------------------------------

class _UnsupportedHostnameBlock extends HostnameBlock {
  _UnsupportedHostnameBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Hostname is not supported on ${_facts.os.name}. '
      'Currently supported: Linux.',
    );
  }

  @override
  Future<void> rollback() async {}
}
