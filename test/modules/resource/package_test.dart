import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/modules/resource/package.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  group('FilePackageModule', () {
    late FilePackageModule packageModule;
    late FileSystem fileSystem;

    setUp(() {
      fileSystem = MemoryFileSystem();
    });

    test('should initialize with default values', () {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(packageModule.packageManager, equals('auto'));
      expect(packageModule.packages, isEmpty);
      expect(packageModule.packageVersions, isEmpty);
      expect(packageModule.repositories, isEmpty);
      expect(packageModule.operation, equals('install'));
      expect(packageModule.force, isFalse);
      expect(packageModule.updateCache, isTrue);
      expect(packageModule.skipIfInstalled, isTrue);
      expect(packageModule.packageId, equals(0));
      expect(packageModule.operationResults, isEmpty);
      expect(packageModule.packagesProcessed, equals(0));
      expect(packageModule.packagesSkipped, equals(0));
      expect(packageModule.errorsEncountered, equals(0));
    });

    test('should load configuration from action properties', () {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {
          'package_manager': 'apt',
          'packages': ['vim', 'git', 'curl'],
          'package_versions': {'vim': '2.1.0', 'git': '2.40.0'},
          'repositories': ['ppa:example/ppa'],
          'operation': 'install',
          'force': true,
          'update_cache': false,
          'skip_if_installed': false,
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(packageModule.packageManager, equals('apt'));
      expect(packageModule.packages, equals(['vim', 'git', 'curl']));
      expect(packageModule.packageVersions, equals({'vim': '2.1.0', 'git': '2.40.0'}));
      expect(packageModule.repositories, equals(['ppa:example/ppa']));
      expect(packageModule.operation, equals('install'));
      expect(packageModule.force, isTrue);
      expect(packageModule.updateCache, isFalse);
      expect(packageModule.skipIfInstalled, isFalse);
    });

    test('should handle missing packages error', () async {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(
        () => packageModule.execute(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No packages specified'),
        )),
      );
    });

    test('should perform rollback successfully', () async {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {},
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      // Rollback should not throw
      await expectLater(packageModule.rollback(), completes);
    });

    test('should handle different operation types', () {
      final operations = ['install', 'uninstall', 'upgrade', 'reinstall'];
      
      for (final operation in operations) {
        final action = Action(
          id: 'test-package-$operation',
          type: 'package',
          properties: {
            'packages': ['vim'],
            'operation': operation,
          },
        );
        final resource = ResourceModel(
          id: 'test-resource',
          source: '/tmp',
          destination: '/tmp',
          type: 'package',
          actions: [],
        );

        final module = FilePackageModule(resource, action, fileSystem: fileSystem);
        expect(module.operation, equals(operation));
      }
    });

    test('should handle package manager specification', () {
      final managers = ['apt', 'pacman', 'pamac', 'docker', 'auto'];
      
      for (final manager in managers) {
        final action = Action(
          id: 'test-package-$manager',
          type: 'package',
          properties: {
            'packages': ['vim'],
            'package_manager': manager,
          },
        );
        final resource = ResourceModel(
          id: 'test-resource',
          source: '/tmp',
          destination: '/tmp',
          type: 'package',
          actions: [],
        );

        final module = FilePackageModule(resource, action, fileSystem: fileSystem);
        expect(module.packageManager, equals(manager));
      }
    });

    test('should handle boolean configuration options', () {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {
          'packages': ['vim'],
          'force': true,
          'update_cache': false,
          'skip_if_installed': false,
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(packageModule.force, isTrue);
      expect(packageModule.updateCache, isFalse);
      expect(packageModule.skipIfInstalled, isFalse);
    });

    test('should handle package versions configuration', () {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {
          'packages': ['vim', 'git'],
          'package_versions': {
            'vim': '2.1.0',
            'git': '2.40.0',
            'curl': '7.68.0',
          },
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(packageModule.packageVersions, equals({
        'vim': '2.1.0',
        'git': '2.40.0',
        'curl': '7.68.0',
      }));
    });

    test('should handle repositories configuration', () {
      final action = Action(
        id: 'test-package',
        type: 'package',
        properties: {
          'packages': ['vim'],
          'repositories': [
            'ppa:example/ppa',
            'https://example.com/repo',
            'deb http://example.com/deb stable main',
          ],
        },
      );
      final resource = ResourceModel(
        id: 'test-resource',
        source: '/tmp',
        destination: '/tmp',
        type: 'package',
        actions: [],
      );

      packageModule = FilePackageModule(resource, action, fileSystem: fileSystem);

      expect(packageModule.repositories, equals([
        'ppa:example/ppa',
        'https://example.com/repo',
        'deb http://example.com/deb stable main',
      ]));
    });
  });
}