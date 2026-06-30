import 'package:configr/src/multi_host/inventory.dart' show Inventory;
import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:configr/src/di.dart';
import 'base_command.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:path/path.dart' as p;

class DiffCommand extends BaseCommand {
  DiffCommand() {
    argParser.addMultiOption(
      'target',
      help: 'Show diff for specific host(s) (can be specified multiple times)',
      valueHelp: 'hostname',
    );
  }

  @override
  String get name => 'diff';

  @override
  String get description => 'Show configuration differences across hosts';

  @override
  Future<void> executeCommand() async {
    final targets = argResults?['target'] as List<String>?;

    if (targets != null && targets.isNotEmpty) {
      await _showHostDiffs(targets);
    } else {
      await _executeV2();
    }
  }

  Future<void> _showHostDiffs(List<String> targetNames) async {
    io.title('Host Diff');

    try {
      final resolved = await runtime.resolveConfig();
      if (resolved == null) {
        io.error('Configuration file not found.');
        return;
      }

      final inventory = resolved.inventory;
      if (inventory is! Inventory) {
        io.warn('No inventory defined.');
        return;
      }

      for (final name in targetNames) {
        final host = inventory.getHost(name);
        if (host == null) {
          io.warn('Host "$name" not found in inventory — skipping.');
          continue;
        }
        await _printHostDiff(host, name);
      }
    } catch (e) {
      io.error('Host diff failed: $e');
      logger.error('Diff error: $e');
    }
  }

  Future<void> _printHostDiff(Host host, String hostName) async {
    io.section('$hostName (${host.address})');

    final configPath = configrConfig.configPath;
    if (configPath == null) return;

    final lockPath = p.join(
      p.dirname(p.absolute(configPath)),
      '${p.basename(configPath)}.$hostName.lock.json',
    );

    final fs = di<FileSystem>();
    if (!await fs.file(lockPath).exists()) {
      io.info('  No lockfile — host has not been applied yet.');
      return;
    }

    try {
      final lockMgr = V2LockfileManager(lockPath, fileSystem: fs);
      final lockData = await lockMgr.read();

      if (lockData.appliedBlocks.isEmpty) {
        io.info('  Lockfile is empty.');
        return;
      }

      for (final block in lockData.appliedBlocks) {
        final statusIcon = switch (block.status) {
          'completed' => '✅',
          'failed' => '❌',
          _ => '⏳',
        };
        io.line('  $statusIcon ${block.blockType}: ${block.id}');
        if (block.source.isNotEmpty) {
          io.line('     source: ${block.source}');
        }
        if (block.destination.isNotEmpty) {
          io.line('     destination: ${block.destination}');
        }
      }
    } catch (e) {
      io.warn('  Could not read lockfile: $e');
    }
  }

  Future<void> _executeV2() async {
    io.title('Configuration Diff');

    try {
      final blocks = await runtime.parseAndCollect();
      io.section('Found ${blocks.length} action block(s)');
      for (final snapshot in blocks) {
        final status = snapshot.status ?? 'pending';
        final icon = switch (status) {
          'completed' => '✅',
          'failed' => '❌',
          _ => '⏳',
        };
        io.line(
          '  $icon ${snapshot.blockType}: ${snapshot.id.isEmpty ? '(unnamed)' : snapshot.id}',
        );
        if (snapshot.source.isNotEmpty) {
          io.line('     source: ${snapshot.source}');
        }
        if (snapshot.destination.isNotEmpty) {
          io.line('     destination: ${snapshot.destination}');
        }
      }
      io.success('Diff complete — ${blocks.length} blocks parsed.');
    } catch (e) {
      io.error('Diff failed: $e');
      logger.error('Diff error: $e');
    }
  }
}
