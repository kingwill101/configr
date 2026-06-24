import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Manages command alternatives (update-alternatives) — Ansible-style dispatch.
///
/// Ansible reference: community.general.alternatives — supports state
/// (present/selected/auto/absent), subcommands (slaves), family, priority.
abstract class AlternativesBlock extends ActionBlock {
  @override
  String get blockType => 'alternatives';

  String name = '';
  String path = '';
  String link = '';
  int priority = 50;
  String linkState = 'selected';
  List<Map<String, String>> subcommands = [];

  factory AlternativesBlock() {
    final facts = OsFacts.detect();
    switch (facts.family) {
      case OsFamily.debian:
        return _DebianAlternativesBlock();
      case OsFamily.redhat:
        return _RedHatAlternativesBlock(facts);
      default:
        return _UnsupportedAlternativesBlock(facts);
    }
  }

  AlternativesBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (path.isNotEmpty) 'path': path,
    if (link.isNotEmpty) 'link': link,
    if (priority != 50) 'priority': priority.toString(),
    if (linkState != 'selected') 'state': linkState,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    path = '';
    link = '';
    priority = 50;
    linkState = 'selected';
    subcommands = [];
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    path = (context.getVariable('path') as String?) ?? '';
    link = (context.getVariable('link') as String?) ?? '';
    priority = (context.getVariable('priority') as int?) ?? 50;
    linkState = (context.getVariable('state') as String?) ?? 'selected';

    final subcmds = context.getVariable('subcommands');
    if (subcmds is List) {
      subcommands = subcmds.cast<Map<String, String>>();
    }
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '';
    return '$blockType: $name -> $path ($linkState)';
  }
}

// ---------------------------------------------------------------------------
// Debian/Ubuntu — update-alternatives --install / --set / --remove / --auto
// ---------------------------------------------------------------------------

class _DebianAlternativesBlock extends AlternativesBlock {
  _DebianAlternativesBlock() : super._();

  @override
  Future<void> execute() async {
    if (name.isEmpty) {
      throw ActionFailedException(
        'Name is required for alternatives',
        moduleId: id,
      );
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Managing alternative: $name'),
    );

    try {
      final priv = privilegeEscalation;

      switch (linkState) {
        case 'absent':
          await _handleAbsent(priv);
        case 'present':
          await _handlePresent(priv);
        case 'auto':
          await _handleAuto(priv);
        case 'selected':
        default:
          await _handleSelected(priv);
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Alternative $name set to $linkState',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('alternatives failed: $e', moduleId: id);
    }
  }

  Future<void> _handleSelected(dynamic priv) async {
    if (path.isEmpty) {
      throw ActionFailedException(
        'Path is required when state=selected',
        moduleId: id,
      );
    }

    // Install first if needed
    if (link.isNotEmpty) {
      final args = <String>['--install', link, name, path, priority.toString()];
      for (final subcmd in subcommands) {
        args.addAll([
          '--slave',
          subcmd['link']!,
          subcmd['name']!,
          subcmd['path']!,
        ]);
      }
      final installResult = await priv.runWithElevatedPrivileges(
        'update-alternatives',
        args,
      );
      if (installResult.exitCode != 0) {
        throw ActionFailedException(
          'Failed to install alternative: ${installResult.stderr}',
          moduleId: id,
        );
      }
    }

    // Set as selected
    final setResult = await priv.runWithElevatedPrivileges(
      'update-alternatives',
      ['--set', name, path],
    );
    if (setResult.exitCode != 0) {
      throw ActionFailedException(
        'Failed to set alternative: ${setResult.stderr}',
        moduleId: id,
      );
    }
  }

  Future<void> _handlePresent(dynamic priv) async {
    if (path.isEmpty) {
      throw ActionFailedException(
        'Path is required when state=present',
        moduleId: id,
      );
    }
    if (link.isEmpty) {
      throw ActionFailedException(
        'Link is required when state=present on Debian',
        moduleId: id,
      );
    }

    final args = <String>['--install', link, name, path, priority.toString()];
    for (final subcmd in subcommands) {
      args.addAll([
        '--slave',
        subcmd['link']!,
        subcmd['name']!,
        subcmd['path']!,
      ]);
    }
    final result = await priv.runWithElevatedPrivileges(
      'update-alternatives',
      args,
    );
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to install alternative: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  Future<void> _handleAuto(dynamic priv) async {
    // Install if needed
    if (path.isNotEmpty && link.isNotEmpty) {
      final args = <String>['--install', link, name, path, priority.toString()];
      for (final subcmd in subcommands) {
        args.addAll([
          '--slave',
          subcmd['link']!,
          subcmd['name']!,
          subcmd['path']!,
        ]);
      }
      await priv.runWithElevatedPrivileges('update-alternatives', args);
    }

    // Set to auto mode
    final result = await priv.runWithElevatedPrivileges('update-alternatives', [
      '--auto',
      name,
    ]);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to set auto mode: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  Future<void> _handleAbsent(dynamic priv) async {
    if (path.isEmpty) {
      throw ActionFailedException(
        'Path is required to remove alternative',
        moduleId: id,
      );
    }

    final result = await priv.runWithElevatedPrivileges('update-alternatives', [
      '--remove',
      name,
      path,
    ]);
    if (result.exitCode != 0) {
      throw ActionFailedException(
        'Failed to remove alternative: ${result.stderr}',
        moduleId: id,
      );
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// RHEL/Fedora (not yet implemented)
// ---------------------------------------------------------------------------

class _RedHatAlternativesBlock extends AlternativesBlock {
  _RedHatAlternativesBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Alternatives on RHEL/Fedora is not yet implemented. '
      'Detected: ${_facts.family.name}.',
    );
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Unsupported OS placeholder
// ---------------------------------------------------------------------------

class _UnsupportedAlternativesBlock extends AlternativesBlock {
  _UnsupportedAlternativesBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Alternatives is only supported on Debian/Ubuntu Linux. '
      'Detected: ${_facts.family.name}.',
    );
  }

  @override
  Future<void> rollback() async {}
}
