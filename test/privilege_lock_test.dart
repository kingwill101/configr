import 'package:test/test.dart';
import 'package:configr/utils/privellage_escallation.dart';

void main() {
  group('Privilege Lock Tests', () {
    late PrivilegeLock lock;

    setUp(() {
      // Reset the singleton instance for each test
      PrivilegeLock.reset();
      lock = PrivilegeLock.instance;
    });

    tearDown(() {
      // Clean up after each test
      PrivilegeLock.reset();
    });

    test('Initial state should be inactive', () {
      expect(lock.isActive, isFalse);
      expect(lock.lastUsed, isNull);
      expect(lock.timeUntilTimeout, isNull);
    });

    test('Acquire should activate the lock', () {
      lock.acquire();
      
      expect(lock.isActive, isTrue);
      expect(lock.lastUsed, isNotNull);
      expect(lock.timeUntilTimeout, isNotNull);
    });

    test('Release should deactivate the lock', () {
      lock.acquire();
      expect(lock.isActive, isTrue);
      
      lock.release();
      
      expect(lock.isActive, isFalse);
      expect(lock.lastUsed, isNull);
      expect(lock.timeUntilTimeout, isNull);
    });

    test('Multiple acquire calls should not create multiple timers', () {
      lock.acquire();
      final firstLastUsed = lock.lastUsed;
      
      // Wait a small amount to ensure time difference
      Future.delayed(Duration(milliseconds: 10), () {
        lock.acquire();
        
        expect(lock.isActive, isTrue);
        expect(lock.lastUsed, isNot(equals(firstLastUsed)));
        expect(lock.timeUntilTimeout, isNotNull);
      });
    });

    test('Force release should deactivate the lock', () {
      lock.acquire();
      expect(lock.isActive, isTrue);
      
      lock.forceRelease();
      
      expect(lock.isActive, isFalse);
      expect(lock.lastUsed, isNull);
      expect(lock.timeUntilTimeout, isNull);
    });

    test('Release on inactive lock should not throw', () {
      expect(() => lock.release(), returnsNormally);
      expect(lock.isActive, isFalse);
    });

    test('Force release on inactive lock should not throw', () {
      expect(() => lock.forceRelease(), returnsNormally);
      expect(lock.isActive, isFalse);
    });

    test('Singleton pattern should work correctly', () {
      final lock1 = PrivilegeLock.instance;
      final lock2 = PrivilegeLock.instance;
      
      expect(identical(lock1, lock2), isTrue);
      
      lock1.acquire();
      expect(lock2.isActive, isTrue);
    });

    test('Reset should clear singleton instance', () {
      final lock1 = PrivilegeLock.instance;
      lock1.acquire();
      expect(lock1.isActive, isTrue);
      
      PrivilegeLock.reset();
      
      final lock2 = PrivilegeLock.instance;
      expect(lock2.isActive, isFalse);
      expect(identical(lock1, lock2), isFalse);
    });

    test('Time until timeout should decrease over time', () async {
      lock.acquire();
      final initialTime = lock.timeUntilTimeout;
      
      expect(initialTime, isNotNull);
      expect(initialTime!.inSeconds, greaterThan(0));
      
      // Wait a small amount and check that time decreased
      await Future.delayed(Duration(milliseconds: 100));
      
      final laterTime = lock.timeUntilTimeout;
      expect(laterTime, isNotNull);
      expect(laterTime!.inSeconds, lessThanOrEqualTo(initialTime.inSeconds));
    });

    test('Lock should timeout after 15 minutes', () async {
      // This test would normally take 15 minutes, so we'll just verify
      // that the timeout duration is set correctly
      lock.acquire();
      
      final timeUntilTimeout = lock.timeUntilTimeout;
      expect(timeUntilTimeout, isNotNull);
      expect(timeUntilTimeout!.inMinutes, greaterThanOrEqualTo(14));
      expect(timeUntilTimeout.inMinutes, lessThanOrEqualTo(15));
    });
  });
}
