import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class AuthorizedKeyBlock extends ActionBlock {
  @override
  String get blockType => 'authorized_key';

  String user = '';
  String key = '';
  String keyOptions = '';
  String path = '';
  bool manageDir = true;
  bool exclusive = false;

  AuthorizedKeyBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (user.isNotEmpty) 'user': user,
    if (key.isNotEmpty) 'key': key,
    if (keyOptions.isNotEmpty) 'key_options': keyOptions,
    if (path.isNotEmpty) 'path': path,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!manageDir) 'manage_dir': manageDir,
    if (exclusive) 'exclusive': exclusive,
  };

  @override
  void resetState() {
    super.resetState();
    user = '';
    key = '';
    keyOptions = '';
    path = '';
    manageDir = true;
    exclusive = false;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    user = (context.getVariable('user') as String?) ?? '';
    key = (context.getVariable('key') as String?) ?? '';
    keyOptions = (context.getVariable('key_options') as String?) ?? '';
    path = (context.getVariable('path') as String?) ?? '';
    manageDir = switch (context.getVariable('manage_dir')) {
      false || 'false' => false,
      _ => true,
    };
    exclusive = switch (context.getVariable('exclusive')) {
      true || 'true' => true,
      _ => false,
    };
  }

  @override
  String dryRunSummary() {
    if (user.isEmpty) return '$blockType: (empty)';
    return '$blockType: $user';
  }

  String _resolvePath() {
    if (path.isNotEmpty) return path;
    final home = user == 'root' ? '/root' : '/home/$user';
    return '$home/.ssh/authorized_keys';
  }

  @override
  Future<void> execute() async {
    if (user.isEmpty || key.isEmpty) {
      throw ActionFailedException(
        'user and key are required for authorized_key',
        moduleId: id,
      );
    }

    emitEvent(
      StartedEvent(moduleId: id, message: 'Managing authorized_keys for $user'),
    );

    try {
      final keyPath = _resolvePath();
      final sshDir = keyPath.replaceAll('/authorized_keys', '');

      if (manageDir && status != 'absent') {
        await fileService.createDirectory(sshDir);
        await fileService.chmod(sshDir, '700');
        final userInfo = await executionService.run('id', ['-u', user]);
        if (userInfo.exitCode == 0) {
          await executionService.run('chown', ['-R', user, sshDir]);
        }
      }

      final file = fileSystem.file(keyPath);
      List<String> lines = [];
      if (await file.exists()) {
        lines = await file.readAsLines();
      } else if (status == 'absent') {
        status = 'completed';
        emitEvent(
          CompletedEvent(
            moduleId: id,
            message: 'Authorized_keys file does not exist for $user',
          ),
        );
        return;
      }

      final fullKey = keyOptions.isNotEmpty ? '$keyOptions $key' : key;

      if (status == 'absent') {
        lines.removeWhere((l) => l.contains(key.trim().split(' ').last));
      } else {
        if (exclusive) {
          lines = [fullKey];
        } else {
          final keyFingerprint = key.trim().split(' ').last;
          final existingIndex = lines.indexWhere(
            (l) => l.contains(keyFingerprint),
          );
          if (existingIndex >= 0) {
            lines[existingIndex] = fullKey;
          } else {
            lines.add(fullKey);
          }
        }
        await file.create(recursive: true);
      }

      await file.writeAsString('${lines.join('\n')}\n');
      await fileService.chmod(keyPath, '600');
      final userInfo = await executionService.run('id', ['-u', user]);
      if (userInfo.exitCode == 0) {
        await executionService.run('chown', ['-R', user, keyPath]);
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message:
              'Key ${status == 'absent' ? 'removed from' : 'added to'} $keyPath',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('authorized_key failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {
    // No automatic rollback for authorized_key
  }
}
