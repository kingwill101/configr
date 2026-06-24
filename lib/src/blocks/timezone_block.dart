import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Sets the system timezone — Ansible-style platform subclass dispatch.
abstract class TimezoneBlock extends ActionBlock {
  @override
  String get blockType => 'timezone';

  String timezone = '';

  factory TimezoneBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxTimezoneBlock();
      case OperatingSystem.macos:
        return _MacOSTimezoneBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDTimezoneBlock();
      default:
        throw UnsupportedError(
          'Timezone not supported on ${Platform.operatingSystem}. '
          'Currently supported: Linux.',
        );
    }
  }

  TimezoneBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (timezone.isNotEmpty) 'timezone': timezone,
  };

  @override
  void resetState() {
    super.resetState();
    timezone = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    timezone = (context.getVariable('timezone') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    return timezone.isNotEmpty ? '$blockType: $timezone' : '';
  }
}

// ---------------------------------------------------------------------------
// Linux — timedatectl → /etc/localtime symlink fallback
// ---------------------------------------------------------------------------

class _LinuxTimezoneBlock extends TimezoneBlock {
  _LinuxTimezoneBlock() : super._();

  @override
  Future<void> execute() async {
    if (timezone.isEmpty) {
      throw ActionFailedException(
        'Timezone is required for timezone block', moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id, message: 'Setting timezone to: $timezone',
    ));

    try {
      final priv = privilegeEscalation;

      final result = await priv.runWithElevatedPrivileges(
        'timedatectl', ['set-timezone', timezone],
      );
      if (result.exitCode != 0) {
        final fallback = await priv.runWithElevatedPrivileges(
          'ln', ['-sf', '/usr/share/zoneinfo/$timezone', '/etc/localtime'],
        );
        if (fallback.exitCode != 0) {
          throw ActionFailedException(
            'Failed to set timezone: ${result.stderr}', moduleId: id,
          );
        }
      }

      emitEvent(CompletedEvent(
        moduleId: id, message: 'Timezone set to $timezone',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('timezone failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// macOS stub  (systemsetup -settimezone)
// ---------------------------------------------------------------------------

class _MacOSTimezoneBlock extends TimezoneBlock {
  _MacOSTimezoneBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Timezone on macOS is not yet implemented. '
      'Use systemsetup -settimezone manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// FreeBSD stub  (tzsetup)
// ---------------------------------------------------------------------------

class _FreeBSDTimezoneBlock extends TimezoneBlock {
  _FreeBSDTimezoneBlock() : super._();

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Timezone on FreeBSD is not yet implemented. '
      'Use tzsetup manually.',
    );
  }

  @override
  Future<void> rollback() async {}
}
