import 'package:configr/exceptions.dart';
import 'package:configr/models/config.dart';

import 'package:test/test.dart';

import 'helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() async {
    helper = TestHelper();
    // Ensure config directory and file exist
    await helper.createTestConfig('''
      resources {
        resource {
          source "input/bashrc"
          destination "output/bashrc"
          actions {
            copy {
              status "pending"
            }
            permissions {
              status "pending"
              mode "644"
            }
          }
        }
      }
      packages {
        package {
          name "git"
          manager "apt"
          status "pending"
        }
        package {
          name "vim"
          manager "apt"
          status "pending"
        }
      }
    ''');
  });

  test('loadConfig loads configuration correctly', () async {
    // Act
    await helper.configManager.load();

    // Assert
    expect(helper.configManager.config.resources.length, 1);
    expect(helper.configManager.config.resources[0].source,
        contains('input/bashrc'));
    expect(helper.configManager.config.resources[0].destination,
        contains('output/bashrc'));
    expect(helper.configManager.config.resources[0].actions.length, 2);
    expect(helper.configManager.config.resources[0].actions[0].type, 'copy');
    expect(helper.configManager.config.resources[0].actions[1].type,
        'permissions');

    expect(helper.configManager.config.packages[0].name, contains('git'));
    expect(helper.configManager.config.packages[0].manager, contains('apt'));
    expect(helper.configManager.config.packages[1].name, contains('vim'));
    expect(helper.configManager.config.packages[1].manager, contains('apt'));
  });

  group('error handling', () {
    test('stops on first error with failFast=true', () async {
      // Arrange
      await helper.createTestConfig('''
        resources {
          resource {
            source "input/invalidfile"
            destination "/invalid/path/file"
            actions {
              copy {
                status "pending"
              }
            }
          }
          resource {
            source "also/invalid"
            destination "/another/invalid/path"
            actions {
              copy {
                status "pending"
              }
            }
          }
        }
      ''');

      helper.configManager.options = const ConfigOptions(failFast: true);

      // Act & Assert
      await helper.configManager.load();
      try {
        await helper.configManager.applyConfig();
        fail('Expected exception was not thrown');
      } on ConfigurationFailedException {
        expect(
            helper.configManager.config.resources[0].status, equals('failed'));
        expect(helper.configManager.config.resources[1].status, isNull);
      }
    });

    test('collects all errors with failFast=false', () async {
      // Arrange
      await helper.createTestConfig('''
        resources {
          resource {
            source "input/file1"
            destination "/invalid/path1"
            actions {
              copy {
                status "pending"
              }
            }
          }
          resource {
            source "input/file2"
            destination "/invalid/path2"
            actions {
              copy {
                status "pending"
              }
            }
          }
        }
      ''');

      helper.configManager.options = const ConfigOptions(failFast: false);
      // Act & Assert
      await helper.configManager.load();
      try {
        await helper.configManager.applyConfig();
        fail('Expected exception was not thrown');
      } on ConfigurationFailedException catch (e) {
        expect(e.errors.length, equals(2));
        expect(
            helper.configManager.config.resources[0].status, equals('failed'));
        expect(
            helper.configManager.config.resources[1].status, equals('failed'));
      }
    });
  });

  test('applyConfig processes resources correctly', () async {
    // Arrange
    await helper.createTestFile('input/bashrc', 'test content');

    await helper.createTestConfig('''
        resource {
          source "input/bashrc"
          destination "output/bashrc"
          actions {
            copy {
              status "pending"
            }
          }
      }
''');

    // Act
    await helper.configManager.load();
    try {
      await helper.configManager.applyConfig();
    } on ConfigurationFailedException catch (e) {
      fail("Not suppose to throw and exception $e");
    } finally {
      // Assert
      await helper.verifyFileContent('output/bashrc', 'test content');
    }
  });

  test('handles missing source file correctly', () async {
    // Arrange
    await helper.createTestConfig('''
        resources {
          resource {
            source "nonexistent/file"
            destination "output/file"
            actions {
              copy {
                status "pending"
              }
            }
          }
        }
      ''');

    // Act & Assert
    await helper.configManager.load();

    expectLater(helper.configManager.applyConfig(),
        throwsA(isA<ConfigurationFailedException>()));
  });
}
