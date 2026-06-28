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

    test('acquire creates lock directory', () {
      final acquired = lock.acquire('web-01');
      expect(acquired, isTrue);

      final lockDir = fs.directory('/test/.configr/locks/web-01');
      expect(lockDir.existsSync(), isTrue);
    });

    test('acquire returns true for new lock', () {
      expect(lock.acquire('web-01'), isTrue);
    });

    test('acquire returns false when lock already held', () {
      lock.acquire('web-01');
      expect(lock.acquire('web-01'), isFalse);
    });

    test('isLocked returns true when lock is held', () {
      lock.acquire('web-01');
      expect(lock.isLocked('web-01'), isTrue);
    });

    test('isLocked returns false when lock is not held', () {
      expect(lock.isLocked('web-01'), isFalse);
    });

    test('release removes lock directory', () {
      lock.acquire('web-01');
      lock.release('web-01');

      final lockDir = fs.directory('/test/.configr/locks/web-01');
      expect(lockDir.existsSync(), isFalse);
    });

    test('release is safe when no lock exists', () {
      lock.release('web-01');
      // no exception should be thrown
    });

    test('releaseAll removes all locks', () async {
      lock.acquire('web-01');
      lock.acquire('db-01');

      lock.releaseAll();

      expect(lock.isLocked('web-01'), isFalse);
      expect(lock.isLocked('db-01'), isFalse);
    });

    test('lockedHosts returns list of locked host names', () {
      lock.acquire('web-01');
      lock.acquire('db-01');

      final hosts = lock.lockedHosts();
      expect(hosts, containsAll(['web-01', 'db-01']));
    });

    test('lockedHosts returns empty list when no locks', () {
      expect(lock.lockedHosts(), isEmpty);
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
