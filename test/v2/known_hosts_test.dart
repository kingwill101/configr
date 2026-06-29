import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse known_hosts block properties', () async {
    final blocks = await helper.processConfig('''
      known_hosts {
        name = "github.com"
        key = "ssh-ed25519 AAAAC3... test@test"
        path = "/etc/ssh/ssh_known_hosts"
        hash_host = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('known_hosts'));
    expect(block.name, equals('github.com'));
    expect(block.key, contains('ssh-ed25519'));
    expect(block.path, equals('/etc/ssh/ssh_known_hosts'));
    expect(block.hashHost, isTrue);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      known_hosts {
        name = "example.com"
        key = "ssh-rsa AAAAB3..."
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('example.com'));
    expect(block.path, isEmpty);
    expect(block.hashHost, isFalse);
  });

  test('should fail when name is missing', () async {
    await helper.runConfig('''
      known_hosts {
        key = "ssh-rsa AAAAB3..."
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when key is missing', () async {
    await helper.runConfig('''
      known_hosts {
        name = "example.com"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should add host entry to known_hosts file', () async {
    await helper.createFile(
      '/etc/ssh/ssh_known_hosts',
      'existing.host ssh-rsa AAAAB3...\n',
    );

    final blocks = await helper.runConfig('''
      known_hosts {
        name = "github.com"
        key = "ssh-ed25519 AAAAC3..."
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/ssh/ssh_known_hosts');
    expect(content, contains('github.com'));
    expect(content, contains('ssh-ed25519 AAAAC3...'));
    expect(content, contains('existing.host'));
  });

  test('should remove host entry from known_hosts file', () async {
    await helper.createFile(
      '/etc/ssh/ssh_known_hosts',
      'github.com ssh-ed25519 AAAAC3...\nexample.com ssh-rsa AAAAB3...\n',
    );

    final blocks = await helper.runConfig('''
      known_hosts {
        name = "github.com"
        key = "ssh-ed25519 AAAAC3..."
        status = "absent"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/ssh/ssh_known_hosts');
    expect(content, isNot(contains('github.com')));
    expect(content, contains('example.com'));
  });

  test('should update existing host entry', () async {
    await helper.createFile(
      '/etc/ssh/ssh_known_hosts',
      'github.com ssh-ed25519 OLDKEY\n',
    );

    final blocks = await helper.runConfig('''
      known_hosts {
        name = "github.com"
        key = "ssh-ed25519 NEWKEY"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/ssh/ssh_known_hosts');
    expect(content, contains('ssh-ed25519 NEWKEY'));
    expect(content, isNot(contains('OLDKEY')));
  });

  test('should use custom path', () async {
    final blocks = await helper.runConfig('''
      known_hosts {
        name = "gitlab.com"
        key = "ssh-ed25519 AAAA..."
        path = "/home/user/.ssh/known_hosts"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/home/user/.ssh/known_hosts');
    expect(content, contains('gitlab.com'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      known_hosts {
        name = "github.com"
        key = "ssh-ed25519 AAAA..."
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('known_hosts: github.com'));
  });

  test('should return correct dry-run summary empty', () async {
    final blocks = await helper.processConfig('''
      known_hosts {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('known_hosts: (empty)'));
  });
}
