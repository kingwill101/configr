import 'package:test/test.dart';
import 'package:configr/src/multi_host/host_rollback.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:file/memory.dart';
import 'package:file/file.dart';

void main() {
  group('HostLockfile', () {
    test('pathFor generates per-host lockfile path', () {
      final path = HostLockfile.pathFor('/etc/configr/config', 'web-01');
      expect(path, equals('/etc/configr/config.web-01.lock.json'));
    });

    test('pathFor works with relative paths', () {
      final path = HostLockfile.pathFor('config', 'db-01');
      expect(path, endsWith('config.db-01.lock.json'));
    });
  });

  group('rollbackHost', () {
    late FileSystem fs;
    late String configPath;

    setUp(() {
      fs = MemoryFileSystem();
      configPath = '/config';
    });

    V2LockfileManager managerFor(String path) {
      return V2LockfileManager(path, fileSystem: fs);
    }

    Future<void> writeLockfile(
      String hostName,
      List<AppliedBlockRecord> records, {
      String? checksum,
    }) async {
      final mgr = managerFor(HostLockfile.pathFor(configPath, hostName));
      await mgr.write(
        V2LockfileData(
          appliedBlocks: records,
          configChecksum: checksum ?? 'abc123',
        ),
      );
    }

    test('returns 0 when no lockfile exists', () async {
      final count = await rollbackHost(
        configPath: configPath,
        hostName: 'web-01',
      );

      expect(count, equals(0));
    });

    test('returns 0 when lockfile is empty', () async {
      await writeLockfile('web-01', []);

      final count = await rollbackHost(
        configPath: configPath,
        hostName: 'web-01',
      );

      expect(count, equals(0));
    });

    test('does not rollback in dry-run mode', () async {
      await writeLockfile('web-01', [
        AppliedBlockRecord(
          blockType: 'file',
          id: '',
          source: '/tmp/test',
          destination: '/tmp/test',
          appliedAt: DateTime.now().toIso8601String(),
        ),
      ]);

      final count = await rollbackHost(
        configPath: configPath,
        hostName: 'web-01',
        dryRun: true,
      );

      expect(count, equals(0));

      // Lockfile should still exist
      final mgr = managerFor(HostLockfile.pathFor(configPath, 'web-01'));
      final data = await mgr.read();
      expect(data, isNotNull);
      expect(data.appliedBlocks, hasLength(1));
    });

    test('deletes lockfile after rolling back all blocks', () async {
      await writeLockfile('web-01', [
        AppliedBlockRecord(
          blockType: 'file',
          id: '',
          source: '/tmp/test',
          destination: '/tmp/test',
          appliedAt: DateTime.now().toIso8601String(),
        ),
      ]);

      await rollbackHost(
        configPath: configPath,
        hostName: 'web-01',
        fileSystem: fs,
      );

      final lockPath = HostLockfile.pathFor(configPath, 'web-01');
      expect(await fs.file(lockPath).exists(), isFalse);
    });

    test(
      'preserves remaining lockfile entries after partial rollback',
      () async {
        final first = AppliedBlockRecord(
          blockType: 'file',
          id: 'first',
          source: '/tmp/first',
          destination: '/tmp/first',
          appliedAt: '2026-01-01T00:00:00.000Z',
        );
        final second = AppliedBlockRecord(
          blockType: 'file',
          id: 'second',
          source: '/tmp/second',
          destination: '/tmp/second',
          appliedAt: '2026-01-01T00:01:00.000Z',
        );
        await writeLockfile('web-01', [first, second]);

        final count = await rollbackHost(
          configPath: configPath,
          hostName: 'web-01',
          count: 1,
          fileSystem: fs,
        );

        expect(count, equals(1));

        final mgr = managerFor(HostLockfile.pathFor(configPath, 'web-01'));
        final data = await mgr.read();
        expect(data, isNotNull);
        expect(data.appliedBlocks, hasLength(1));
        expect(data.appliedBlocks.single.id, equals('first'));
        expect(data.configChecksum, equals('abc123'));
      },
    );
  });
}
