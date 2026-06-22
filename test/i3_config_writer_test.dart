import 'package:configr/src/models/action.dart';
import 'package:configr/src/models/command.dart';
import 'package:configr/src/models/config.dart';
import 'package:configr/src/models/file_model.dart';
import 'package:configr/src/models/package.dart';
import 'package:configr/src/reader/i3_config_reader.dart';
import 'package:configr/src/writer/i3_config_writer.dart';
import 'package:test/test.dart';

void main() {
  group('I3ConfigWriter', () {
    late I3ConfigWriter writer;

    setUp(() {
      writer = I3ConfigWriter();
    });

    group('write basic sections', () {
      test('empty config produces empty string', () {
        final config = Config();
        expect(writer.write(config), isEmpty);
      });

      test('config with resources section', () {
        final config = Config(
          resources: [
            ResourceModel(
              id: 'res1',
              source: 'i3/config',
              destination: '~/.config/i3/config',
              actions: [],
            ),
            ResourceModel(
              id: 'res2',
              source: 'dunst/dunstrc',
              destination: '~/.config/dunst/dunstrc',
              actions: [],
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('resources {'));
        expect(output, contains('resource {'));
        expect(output, contains('source = "i3/config"'));
        expect(output, contains('destination = "~/.config/i3/config"'));
      });

      test('config with commands section', () {
        final config = Config(
          commands: [
            Command(
              name: 'install-dependencies',
              status: 'completed',
              timestamp: '2024-08-21T12:36:00Z',
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('commands {'));
        expect(output, contains('command install-dependencies {'));
        expect(output, contains('status = "completed"'));
      });

      test('config with packages section', () {
        final config = Config(
          packages: [
            Package(
              id: 'pkg1',
              name: 'i3',
              manager: 'apt',
              version: '4.18.2-1',
              scope: 'global',
              status: 'installed',
              timestamp: '2024-08-21T12:36:10Z',
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('packages {'));
        expect(output, contains('package {'));
        expect(output, contains('name = "i3"'));
        expect(output, contains('manager = "apt"'));
        expect(output, contains('version = "4.18.2-1"'));
        expect(output, contains('scope = "global"'));
      });

      test('config with scripts', () {
        final config = Config(
          preApplyScripts: ['echo "hello"', 'cd /tmp'],
          postApplyScripts: ['rm -rf /tmp/cache'],
        );

        final output = writer.write(config);
        // Scripts use `run` as command head
        expect(output, contains('pre_apply_scripts {'));
        expect(output, contains('post_apply_scripts {'));
        expect(output, contains(r'run "echo "hello"""'));
        expect(output, contains('run "cd /tmp"'));
        expect(output, contains(r'run "rm -rf /tmp/cache"'));
      });
    });

    group('write action blocks', () {
      test('config with actions in resources', () {
        final config = Config(
          resources: [
            ResourceModel(
              id: 'res1',
              source: 'i3/config',
              destination: '~/.config/i3/config',
              actions: [
                Action(
                  type: 'copy',
                  status: 'completed',
                  timestamp: '2024-08-21T12:34:56Z',
                ),
                Action(
                  type: 'executable',
                  status: 'completed',
                  timestamp: '2024-08-21T12:34:57Z',
                ),
              ],
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('actions {'));
        expect(output, contains('copy {'));
        expect(output, contains('executable {'));
        expect(output, contains('status = "completed"'));
      });
    });

    group('value quoting', () {
      test('simple alphanumeric values are bare', () {
        final config = Config(
          packages: [
            Package(
              id: 'pkg1',
              name: 'alacritty',
              manager: 'apt',
              scope: 'global',
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('name = alacritty'));
        expect(output, contains('manager = apt'));
        expect(output, contains('scope = global'));
      });

      test('values with spaces are quoted', () {
        final config = Config(
          packages: [
            Package(
              id: 'pkg1',
              name: 'Desktop Tools',
              manager: 'apt',
              scope: 'global',
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains('name = "Desktop Tools"'));
      });

      test('values starting with dollar sign are quoted', () {
        final config = Config(
          packages: [
            Package(
              id: 'pkg1',
              name: 'test',
              manager: r'$custom',
              scope: 'global',
            ),
          ],
        );

        final output = writer.write(config);
        expect(output, contains(r'manager = "\\$custom"'));
      });
    });

    group('round-trip: parse → write → parse', () {
      /// Parse i3 config text, write it back, and verify the written text
      /// parses to an equal config.
      Future<void> assertRoundTrip(String input) async {
        final reader = I3ConfigReader();
        final writer = I3ConfigWriter();

        final config1 = await reader.read(input);
        final output = writer.write(config1);
        final config2 = await reader.read(output);

        expect(
          config2,
          equals(config1),
          reason: 'Round-trip failed.\nInput:\n$input\n\nOutput:\n$output',
        );
      }

      test('simple resources config', () async {
        await assertRoundTrip('''
resources {
  resource {
    source = "i3/config"
    destination = "~/.config/i3/config"
    actions {
      copy {
        status = "completed"
        timestamp = "2024-08-21T12:34:56Z"
      }
      executable {
        status = "completed"
        timestamp = "2024-08-21T12:34:57Z"
      }
    }
  }
}
''');
      });

      test('resources, commands, packages', () async {
        await assertRoundTrip('''
resources {
  resource {
    source = "i3/config"
    destination = "~/.config/i3/config"
    actions {
      copy {
        status = "completed"
        timestamp = "2024-08-21T12:34:56Z"
      }
    }
  }
}

commands {
  command install-dependencies {
    status = "completed"
    timestamp = "2024-08-21T12:36:00Z"
    parameters = "i3 dunst alacritty"
  }
  command update-packages {
    status = "completed"
    timestamp = "2024-08-21T12:36:05Z"
  }
}

packages {
  package {
    name = "i3"
    manager = "apt"
    version = "4.18.2-1"
    scope = "global"
    status = "installed"
    timestamp = "2024-08-21T12:36:10Z"
  }
  package {
    name = "dunst"
    manager = "pip"
    version = "1.5.0"
    scope = "config"
    status = "installed"
    timestamp = "2024-08-21T12:36:20Z"
  }
}
''');
      });

      test('resource with bare values', () async {
        await assertRoundTrip('''
resources {
  resource {
    source = i3/config
    destination = "~/.config/i3/config"
    actions {
      copy {
        status = completed
        timestamp = "2024-08-21T12:34:56Z"
      }
    }
  }
}
''');
      });

      test('empty config', () async {
        await assertRoundTrip('');
      });

      test('config with only resources', () async {
        await assertRoundTrip('''
resources {
  resource {
    source = "test/file"
    destination = "~/test/file"
  }
}
''');
      });

      test('resource without actions', () async {
        await assertRoundTrip('''
resources {
  resource {
    source = "test/file"
    destination = "~/test/file"
  }
}
''');
      });
    });
  });
}
