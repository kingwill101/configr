import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:test/test.dart';

/// Tests for the instance-based [PrivilegeLock] API (Phase K.5).
void main() {
  group('PrivilegeLock v2 instance-based (K.5)', () {
    test('acquire and release cycle', () {
      final lock = PrivilegeLock(timeout: const Duration(minutes: 15));
      expect(lock.isActive, isFalse);

      lock.acquire();
      expect(lock.isActive, isTrue);

      lock.forceRelease();
      expect(lock.isActive, isFalse);
    });

    test('forceRelease invalidates the lock', () {
      final lock = PrivilegeLock(timeout: const Duration(minutes: 15));
      lock.acquire();
      expect(lock.isActive, isTrue);

      lock.forceRelease();
      expect(lock.isActive, isFalse);

      // Re-acquire should work after force release
      lock.acquire();
      expect(lock.isActive, isTrue);
    });

    test('timeout auto-releases lock', () async {
      final lock = PrivilegeLock(timeout: const Duration(milliseconds: 10));

      lock.acquire();
      expect(lock.isActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        lock.isActive,
        isFalse,
        reason: 'Lock should have timed out after 10ms',
      );
    });

    test('timeout can be configured per instance', () {
      final lock1 = PrivilegeLock(timeout: const Duration(minutes: 5));
      final lock2 = PrivilegeLock(timeout: const Duration(minutes: 30));

      lock1.acquire();
      lock2.acquire();

      expect(lock1.isActive, isTrue);
      expect(lock2.isActive, isTrue);

      lock1.forceRelease();
      expect(lock1.isActive, isFalse);
      expect(
        lock2.isActive,
        isTrue,
        reason: 'lock2 should be unaffected by lock1 release',
      );

      lock2.forceRelease();
      expect(lock2.isActive, isFalse);
    });

    test('multiple acquires refresh timeout', () async {
      final lock = PrivilegeLock(timeout: const Duration(milliseconds: 100));

      lock.acquire();
      expect(lock.isActive, isTrue);

      await Future.delayed(const Duration(milliseconds: 30));

      // Re-acquire should refresh the timeout
      lock.acquire();

      // Wait past original timeout but within refreshed timeout
      await Future.delayed(const Duration(milliseconds: 80));

      expect(
        lock.isActive,
        isTrue,
        reason: 'Re-acquire should have refreshed the timeout',
      );
    });
  });
}
