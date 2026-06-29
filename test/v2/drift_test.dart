import 'dart:convert';

import 'package:configr/src/di.dart';
import 'package:configr/src/models/v2_lockfile_data.dart';
import 'package:configr/src/utils/drift_checker.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/utils/v2_lockfile_manager.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:file/memory.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late FileService fileService;
  late String configPath;
  late String lockfilePath;

  setUp(() {
    fs = MemoryFileSystem();
    fs.currentDirectory = fs.directory('/');
    fileService = LocalFileService(fileSystem: fs);
    configPath = '/test/config';
    lockfilePath = V2LockfileManager.lockPathFor(configPath);

    fs.directory('/test').createSync(recursive: true);
    fs.directory('/dest').createSync(recursive: true);

    di
      ..allowReassignment = true
      ..registerSingleton<FileSystem>(fs)
      ..registerSingleton<FileService>(fileService)
      ..allowReassignment = false;
  });

  tearDown(() {
    di.reset();
  });

  group('checkDrift', () {
    test('returns empty list when no lockfile exists', () async {
      final results = await checkDrift(configPath);
      expect(results, isEmpty);
    });

    test('returns empty list when lockfile has no applied blocks', () async {
      await _writeLockfile(V2LockfileData(appliedBlocks: []), lockfilePath, fs);
      final results = await checkDrift(configPath);
      expect(results, isEmpty);
    });

    test('reports unknown for blocks without destination', () async {
      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [_record(blockType: 'echo', destination: '')],
        ),
        lockfilePath,
        fs,
      );
      final results = await checkDrift(configPath);
      expect(results, hasLength(1));
      expect(results[0].state, DriftState.unknown);
    });

    test('reports unknown for blocks without sha256', () async {
      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [
            _record(blockType: 'copy', destination: '/dest/file.txt'),
          ],
        ),
        lockfilePath,
        fs,
      );
      final results = await checkDrift(configPath);
      expect(results, hasLength(1));
      expect(results[0].state, DriftState.unknown);
    });

    test('reports synced when file matches stored checksum', () async {
      const content = 'hello world';
      await fs.file('/dest/file.txt').writeAsString(content);
      final checksum = _hash('/dest/file.txt', content);

      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [
            _record(
              blockType: 'copy',
              destination: '/dest/file.txt',
              sha256: checksum,
            ),
          ],
        ),
        lockfilePath,
        fs,
      );
      final results = await checkDrift(configPath);
      expect(results, hasLength(1));
      expect(results[0].state, DriftState.synced);
    });

    test('reports drifted when file content changed', () async {
      await fs.file('/dest/file.txt').writeAsString('original');
      final checksum = _hash('/dest/file.txt', 'original');

      await fs.file('/dest/file.txt').writeAsString('modified');

      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [
            _record(
              blockType: 'copy',
              destination: '/dest/file.txt',
              sha256: checksum,
            ),
          ],
        ),
        lockfilePath,
        fs,
      );
      final results = await checkDrift(configPath);
      expect(results, hasLength(1));
      expect(results[0].state, DriftState.drifted);
    });

    test('reports missing when file no longer exists', () async {
      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [
            _record(
              blockType: 'copy',
              destination: '/dest/file.txt',
              sha256: 'abc123',
            ),
          ],
        ),
        lockfilePath,
        fs,
      );
      final results = await checkDrift(configPath);
      expect(results, hasLength(1));
      expect(results[0].state, DriftState.missing);
    });

    test('checks multiple blocks independently', () async {
      await fs.file('/dest/a.txt').writeAsString('aaa');
      final hashA = _hash('/dest/a.txt', 'aaa');

      await fs.file('/dest/b.txt').writeAsString('bbb');
      final hashB = _hash('/dest/b.txt', 'bbb');
      await fs.file('/dest/b.txt').writeAsString('changed');

      await _writeLockfile(
        V2LockfileData(
          appliedBlocks: [
            _record(
              blockType: 'copy',
              destination: '/dest/a.txt',
              sha256: hashA,
            ),
            _record(
              blockType: 'copy',
              destination: '/dest/b.txt',
              sha256: hashB,
            ),
            _record(
              blockType: 'copy',
              destination: '/dest/c.txt',
              sha256: 'abc',
            ),
            _record(blockType: 'echo', destination: ''),
            _record(blockType: 'copy', destination: '/dest/d.txt'),
          ],
        ),
        lockfilePath,
        fs,
      );

      final results = await checkDrift(configPath);
      expect(results, hasLength(5));
      expect(results[0].state, DriftState.synced);
      expect(results[1].state, DriftState.drifted);
      expect(results[2].state, DriftState.missing);
      expect(results[3].state, DriftState.unknown);
      expect(results[4].state, DriftState.unknown);
    });
  });
}

Future<void> _writeLockfile(
  V2LockfileData data,
  String lockfilePath,
  FileSystem fs,
) async {
  final mgr = V2LockfileManager(lockfilePath, fileSystem: fs);
  await mgr.write(data);
}

AppliedBlockRecord _record({
  required String blockType,
  String destination = '',
  String? sha256,
}) {
  return AppliedBlockRecord(
    blockType: blockType,
    id: 'test-id',
    source: '',
    destination: destination,
    appliedAt: DateTime.now().toUtc().toIso8601String(),
    sha256: sha256,
  );
}

String _hash(String path, String content) {
  return sha256.convert([
    ...utf8.encode(path),
    ...utf8.encode(content),
  ]).toString();
}
