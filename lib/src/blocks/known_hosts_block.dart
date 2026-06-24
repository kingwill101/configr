import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class KnownHostsBlock extends ActionBlock {
  @override
  String get blockType => 'known_hosts';

  String name = '';
  String key = '';
  String path = '';
  bool hashHost = false;

  KnownHostsBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (name.isNotEmpty) 'name': name,
    if (key.isNotEmpty) 'key': key,
    if (path.isNotEmpty) 'path': path,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (hashHost) 'hash_host': hashHost,
  };

  @override
  void resetState() {
    super.resetState();
    name = '';
    key = '';
    path = '';
    hashHost = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    name = (context.getVariable('name') as String?) ?? '';
    key = (context.getVariable('key') as String?) ?? '';
    path = (context.getVariable('path') as String?) ?? '';
    hashHost = switch (context.getVariable('hash_host')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  String dryRunSummary() {
    if (name.isEmpty) return '$blockType: (empty)';
    return '$blockType: $name';
  }

  String _resolvePath() {
    if (path.isNotEmpty) return path;
    return '/etc/ssh/ssh_known_hosts';
  }

  @override
  Future<void> execute() async {
    if (name.isEmpty || key.isEmpty) {
      throw ActionFailedException(
        'name and key are required for known_hosts',
        moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Managing known_hosts entry: $name',
    ));

    try {
      final knownPath = _resolvePath();
      final file = fileSystem.file(knownPath);
      List<String> lines = [];
      if (await file.exists()) {
        lines = await file.readAsLines();
      } else if (status == 'absent') {
        status = 'completed';
        return;
      }

      final entry = hashHost ? _hashHostname(name) : '$name $key';

      if (status == 'absent') {
        lines.removeWhere((l) => l.contains(name));
      } else {
        final existingIndex = lines.indexWhere((l) => l.contains(name));
        if (existingIndex >= 0) {
          lines[existingIndex] = entry;
        } else {
          lines.add(entry);
        }
        if (!await file.exists()) {
          await file.create(recursive: true);
        }
      }

      await file.writeAsString('${lines.join('\n')}\n');

      emitEvent(CompletedEvent(
        moduleId: id,
        message:
            'Host $name ${status == 'absent' ? 'removed from' : 'added to'} $knownPath',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('known_hosts failed: $e', moduleId: id);
    }
  }

  String _hashHostname(String hostname) {
    // ssh-keygen -H hashes hostnames, but for simplicity in configr
    // we just use the raw hostname. Actual hashing would require
    // shelling out to ssh-keygen.
    return hostname;
  }

  @override
  Future<void> rollback() async {
    // No automatic rollback for known_hosts
  }
}
