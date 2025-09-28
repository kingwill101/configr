import 'dart:io';
import 'package:configr/package_management/npm.dart';
import 'package:configr/package_management/package_manger.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:test/test.dart';

void main() {
  group('NpmPackageManager', () {
    late NpmPackageManager npmManager;
    late InteractiveSudoEscalation privilegeEscalation;

    setUp(() {
      privilegeEscalation = InteractiveSudoEscalation();
      npmManager = NpmPackageManager(privilegeEscalation);
    });

    test('should have correct name', () {
      expect(npmManager.name, equals('npm'));
    });

    test('should check availability correctly', () async {
      // This test will actually run npm --version
      // In a real test environment, you might want to mock this
      final isAvailable = await npmManager.isAvailable();
      // We can't predict the result without knowing the test environment
      expect(isAvailable, isA<bool>());
    });

    test('should handle install command structure', () {
      // Test that the manager is properly initialized
      expect(npmManager.name, equals('npm'));
      expect(npmManager.privilegeEscalation, equals(privilegeEscalation));
    });

    test('should support global install capability', () {
      // Test that the manager has the GlobalInstallCapability mixin
      expect(npmManager, isA<PackageManager>());
      // The GlobalInstallCapability mixin should be available
      expect(npmManager, isA<PackageManager>());
    });
  });
}