import 'package:test/test.dart';
import 'package:configr/src/multi_host/drift_detector.dart';
import 'package:configr/src/multi_host/host_rollback.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:file/memory.dart';
import 'package:file/file.dart';

void main() {
  group('DriftDetector', () {
    late DriftDetector detector;
    late FileSystem fs;
    late String configPath;
    final baseBlocks = [
      AppliedBlockRecord(
        blockType: 'file',
        id: '',
        source: '/tmp/test',
        destination: '/tmp/test',
        appliedAt: '2024-01-01T00:00:00Z',
        sha256: 'abc',
      ),
      AppliedBlockRecord(
        blockType: 'copy',
        id: '',
        source: '/src',
        destination: '/dst',
        appliedAt: '2024-01-01T00:00:00Z',
        sha256: 'def',
      ),
    ];

    setUp(() {
      detector = DriftDetector();
      fs = MemoryFileSystem();
      configPath = '/config';
    });

    Future<void> writeLockfile(String hostName,
        List<AppliedBlockRecord> records, {String? checksum}) async {
      final lockPath = HostLockfile.pathFor(configPath, hostName);
      final mgr = V2LockfileManager(lockPath, fileSystem: fs);
      await mgr.write(V2LockfileData(
        appliedBlocks: records,
        configChecksum: checksum ?? 'abc123',
      ));
    }

    group('checkHost', () {
      test('returns drift when no lockfile exists', () async {
        final result = await detector.checkHost(
          configPath: configPath,
          hostName: 'web-01',
          expectedBlocks: baseBlocks,
          fileSystem: fs,
        );

        expect(result.hasDrift, isTrue);
        expect(result.message, contains('No lockfile'));
      });

      test('returns drift when checksum mismatches', () async {
        await writeLockfile('web-01', baseBlocks, checksum: 'xyz789');

        final result = await detector.checkHost(
          configPath: configPath,
          hostName: 'web-01',
          expectedBlocks: baseBlocks,
          expectedChecksum: 'abc123',
          fileSystem: fs,
        );

        expect(result.hasDrift, isTrue);
        expect(result.message, contains('checksum mismatch'));
      });

      test('returns drift when block count mismatches', () async {
        await writeLockfile('web-01', [baseBlocks.first]);

        final result = await detector.checkHost(
          configPath: configPath,
          hostName: 'web-01',
          expectedBlocks: baseBlocks,
          fileSystem: fs,
        );

        expect(result.hasDrift, isTrue);
        expect(result.message, contains('Block count mismatch'));
      });

      test('returns drift when block content mismatches', () async {
        final modifiedBlocks = [
          baseBlocks[0],
          AppliedBlockRecord(
            blockType: 'delete',
            id: '',
            source: '/other',
            destination: '/other',
            appliedAt: '2024-01-01T00:00:00Z',
          ),
        ];
        await writeLockfile('web-01', modifiedBlocks);

        final result = await detector.checkHost(
          configPath: configPath,
          hostName: 'web-01',
          expectedBlocks: baseBlocks,
          fileSystem: fs,
        );

        expect(result.hasDrift, isTrue);
        expect(result.message, contains('Block mismatch'));
      });

      test('returns no drift when lockfile matches', () async {
        await writeLockfile('web-01', baseBlocks);

        final result = await detector.checkHost(
          configPath: configPath,
          hostName: 'web-01',
          expectedBlocks: baseBlocks,
          expectedChecksum: 'abc123',
          fileSystem: fs,
        );

        expect(result.hasDrift, isFalse);
      });
    });

    group('checkHosts', () {
      test('returns drift results for multiple hosts', () async {
        await writeLockfile('web-01', baseBlocks);
        // web-02 has no lockfile

        final results = await detector.checkHosts(
          configPath: configPath,
          hostNames: ['web-01', 'web-02'],
          expectedBlocks: baseBlocks,
          fileSystem: fs,
        );

        expect(results, hasLength(1));
        expect(results.first.hostName, equals('web-02'));
      });
    });

    group('findUnconfiguredHosts', () {
      test('returns hosts with no lockfile', () async {
        await writeLockfile('web-01', baseBlocks);

        final unconfigured = await detector.findUnconfiguredHosts(
          configPath: configPath,
          hostNames: ['web-01', 'web-02'],
          fileSystem: fs,
        );

        expect(unconfigured, equals(['web-02']));
      });
    });
  });
}
