import 'package:test/test.dart';
import 'package:configr/src/multi_host/host_lock.dart';
import 'package:file/memory.dart';
import 'package:file/file.dart';

void main() {
  group('HostLock', () {
    late FileSystem fs;
    late HostLock lock;

    setUp(() {
      fs = MemoryFileSystem();
      lock = HostLock(baseDir: '/test/.configr', fs: fs);
    });

    test('acquire creates lock directory', () async {
      final acquired = await lock.acquire('web-01');
      expect(acquired, isTrue);

      final lockDir = fs.directory('/test/.configr/locks/web-01');
      expect(await lockDir.exists(), isTrue);
    });

    test('acquire returns true for new lock', () async {
      expect(await lock.acquire('web-01'), isTrue);
    });

    test('acquire returns false when lock already held', () async {
      await lock.acquire('web-01');
      expect(await lock.acquire('web-01'), isFalse);
    });

    test('isLocked returns true when lock is held', () async {
      await lock.acquire('web-01');
      expect(await lock.isLocked('web-01'), isTrue);
    });

    test('isLocked returns false when lock is not held', () async {
      expect(await lock.isLocked('web-01'), isFalse);
    });

    test('release removes lock directory', () async {
      await lock.acquire('web-01');
      await lock.release('web-01');

      final lockDir = fs.directory('/test/.configr/locks/web-01');
      expect(lockDir.existsSync(), isFalse);
    });

    test('release is safe when no lock exists', () async {
      await lock.release('web-01');
      // no exception should be thrown
    });

    test('releaseAll removes all locks', () async {
      await lock.acquire('web-01');
      await lock.acquire('db-01');

      await lock.releaseAll();

      expect(await lock.isLocked('web-01'), isFalse);
      expect(await lock.isLocked('db-01'), isFalse);
    });

    test('lockedHosts returns list of locked host names', () async {
      await lock.acquire('web-01');
      await lock.acquire('db-01');

      final hosts = await lock.lockedHosts();
      expect(hosts, containsAll(['web-01', 'db-01']));
    });

    test('lockedHosts returns empty list when no locks', () async {
      expect(await lock.lockedHosts(), isEmpty);
    });

    test('acquireAsync creates lock asynchronously', () async {
      final acquired = await lock.acquireAsync('web-01');
      expect(acquired, isTrue);
      expect(await lock.isLockedAsync('web-01'), isTrue);
    });

    test('releaseAsync removes lock asynchronously', () async {
      await lock.acquireAsync('web-01');
      await lock.releaseAsync('web-01');
      expect(await lock.isLockedAsync('web-01'), isFalse);
    });
  });
}
