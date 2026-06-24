import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages firewalld services, ports, sources, and rich rules.
///
/// ```i3
/// firewalld {
///   service = "http"
///   zone = "public"
///   state = "enabled"      # enabled | disabled
///   permanent = true
///   immediate = false
/// }
/// ```
abstract class FirewalldBlock extends ActionBlock {
  @override
  String get blockType => 'firewalld';

  String service = '';
  String port = '';
  String zone = 'public';
  String state = '';
  bool permanent = true;
  bool immediate = false;
  String richRule = '';

  factory FirewalldBlock() {
    final facts = OsFacts.detect();
    facts.requireLinux('firewalld');
    return _LinuxFirewalldBlock();
  }

  FirewalldBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (service.isNotEmpty) 'service': service,
    if (port.isNotEmpty) 'port': port,
    if (zone != 'public') 'zone': zone,
    if (state.isNotEmpty) 'state': state,
    if (richRule.isNotEmpty) 'rich_rule': richRule,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (permanent != true) 'permanent': permanent,
    if (immediate) 'immediate': immediate,
  };

  @override
  void resetState() {
    super.resetState();
    service = '';
    port = '';
    zone = 'public';
    state = '';
    permanent = true;
    immediate = false;
    richRule = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    service = (context.getVariable('service') as String?) ?? '';
    port = (context.getVariable('port') as String?) ?? '';
    zone = (context.getVariable('zone') as String?) ?? 'public';
    state = (context.getVariable('state') as String?) ?? '';
    permanent = switch (context.getVariable('permanent')) {
      false || 'false' => false,
      _ => true,
    };
    immediate = switch (context.getVariable('immediate')) {
      true || 'true' => true,
      _ => false,
    };
    richRule = (context.getVariable('rich_rule') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    final parts = <String>[];
    if (service.isNotEmpty) parts.add('service=$service');
    if (port.isNotEmpty) parts.add('port=$port');
    if (source.isNotEmpty) parts.add('source=$source');
    if (richRule.isNotEmpty) parts.add('rich_rule=$richRule');
    if (zone != 'public') parts.add('zone=$zone');
    if (state.isNotEmpty) parts.add('state=$state');
    if (parts.isEmpty) return '';
    return '$blockType: ${parts.join(', ')}';
  }

  Future<ProcessResult> _runFirewallCmd(List<String> args) {
    return runCommand('firewall-cmd', args, requireElevation: true, checkExitCode: false);
  }

  Future<bool> _isRunning() async {
    try {
      final result = await _runFirewallCmd(['--state']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Build base args for a rule modification command.
  List<String> _baseArgs() {
    final args = <String>[];
    if (zone != 'public') {
      args.addAll(['--zone', zone]);
    }
    return args;
  }

  /// Apply a firewall modification for both permanent and/or immediate.
  ///
  /// If [permanent] is true, the change is written to the permanent config
  /// (and a reload is triggered if [immediate] is false).
  /// If [immediate] is true, the change is also applied to the running config.
  Future<void> _applyChange({
    required String action,
    required String value,
  }) async {
    if (permanent) {
      final permArgs = [..._baseArgs(), '--permanent', action, value];
      final result = await _runFirewallCmd(permArgs);
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'firewall-cmd failed: ${result.stderr}',
          moduleId: id,
        );
      }
      if (!immediate) {
        final reloadResult = await _runFirewallCmd(['--reload']);
        if (reloadResult.exitCode != 0) {
          throw ActionFailedException(
            'firewall-cmd --reload failed: ${reloadResult.stderr}',
            moduleId: id,
          );
        }
      }
    }
    if (immediate) {
      final runtimeArgs = [..._baseArgs(), action, value];
      final result = await _runFirewallCmd(runtimeArgs);
      if (result.exitCode != 0) {
        throw ActionFailedException(
          'firewall-cmd failed: ${result.stderr}',
          moduleId: id,
        );
      }
    }
  }

  Future<void> _manageService() async {
    if (service.isEmpty) return;
    if (state == 'enabled') {
      await _applyChange(action: '--add-service', value: service);
    } else if (state == 'disabled') {
      await _applyChange(action: '--remove-service', value: service);
    }
  }

  Future<void> _managePort() async {
    if (port.isEmpty) return;
    if (state == 'enabled') {
      await _applyChange(action: '--add-port', value: port);
    } else if (state == 'disabled') {
      await _applyChange(action: '--remove-port', value: port);
    }
  }

  Future<void> _manageSource() async {
    if (source.isEmpty) return;
    if (state == 'enabled') {
      await _applyChange(action: '--add-source', value: source);
    } else if (state == 'disabled') {
      await _applyChange(action: '--remove-source', value: source);
    }
  }

  Future<void> _manageRichRule() async {
    if (richRule.isEmpty) return;
    if (state == 'enabled') {
      await _applyChange(action: '--add-rich-rule', value: richRule);
    } else if (state == 'disabled') {
      await _applyChange(action: '--remove-rich-rule', value: richRule);
    }
  }

  @override
  Future<void> execute();
  @override
  Future<void> rollback();
}

class _LinuxFirewalldBlock extends FirewalldBlock {
  _LinuxFirewalldBlock() : super._();

  String _previousState = '';
  String _previousService = '';
  String _previousPort = '';
  String _previousSource = '';
  String _previousRichRule = '';

  @override
  Future<void> execute() async {
    if (service.isEmpty && port.isEmpty && source.isEmpty && richRule.isEmpty) {
      throw ActionFailedException(
        'One of service, port, source, or rich_rule is required',
        moduleId: id,
      );
    }
    if (state != 'enabled' && state != 'disabled') {
      throw ActionFailedException(
        'State must be "enabled" or "disabled", got: $state',
        moduleId: id,
      );
    }

    final running = await _isRunning();
    if (!running) {
      throw ActionFailedException(
        'firewalld is not running. Start firewalld before managing rules.',
        moduleId: id,
      );
    }

    _previousState = state;
    _previousService = service;
    _previousPort = port;
    _previousSource = source;
    _previousRichRule = richRule;

    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Managing firewalld rule: $dryRunSummary',
      ),
    );

    try {
      await _manageService();
      await _managePort();
      await _manageSource();
      await _manageRichRule();

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Firewalld rule applied',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('Firewalld failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    if (_previousService.isEmpty &&
        _previousPort.isEmpty &&
        _previousSource.isEmpty &&
        _previousRichRule.isEmpty) {
      return;
    }
    try {
      final originalState = _previousState;
      state = originalState == 'enabled' ? 'disabled' : 'enabled';
      service = _previousService;
      port = _previousPort;
      source = _previousSource;
      richRule = _previousRichRule;

      await _manageService();
      await _managePort();
      await _manageSource();
      await _manageRichRule();

      state = originalState;
    } catch (_) {}
  }
}
