import 'package:configr/src/events/module_events.dart';
import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse cron block properties', () async {
    final blocks = await helper.processConfig('''
      cron {
        name = "daily-backup"
        job = "/usr/bin/backup"
        minute = "0"
        hour = "3"
        day = "*"
        month = "*"
        weekday = "*"
        user = "root"
        disabled = false
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('cron'));
    expect(block.name, equals('daily-backup'));
    expect(block.job, equals('/usr/bin/backup'));
    expect(block.minute, equals('0'));
    expect(block.hour, equals('3'));
    expect(block.user, equals('root'));
    expect(block.disabled, isFalse);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      cron {
        name = "test-job"
        job = "/usr/bin/test"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.minute, equals('*'));
    expect(block.hour, equals('*'));
    expect(block.day, equals('*'));
    expect(block.month, equals('*'));
    expect(block.weekday, equals('*'));
    expect(block.disabled, isFalse);
    expect(block.user, isEmpty);
    expect(block.cronFile, isEmpty);
  });

  test('should fail when name is missing', () async {
    await helper.runConfig('''
      cron {
        job = "/usr/bin/test"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should fail when job is missing', () async {
    await helper.runConfig('''
      cron {
        name = "test-job"
      }
    ''');

    expect(helper.eventOfType<FailedEvent>(), isNotNull);
  });

  test('should write to cron_file when specified', () async {
    final blocks = await helper.runConfig('''
      cron {
        name = "my-job"
        job = "/usr/bin/myjob"
        minute = "*/5"
        cron_file = "/etc/cron.d/myapp"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/cron.d/myapp');
    expect(content, contains('*/5 * * * * /usr/bin/myjob #my-job'));
  });

  test('should update existing entry in cron_file', () async {
    await helper.createFile(
      '/etc/cron.d/myapp',
      '0 3 * * * /usr/bin/oldjob #my-job\n',
    );

    final blocks = await helper.runConfig('''
      cron {
        name = "my-job"
        job = "/usr/bin/newjob"
        minute = "30"
        cron_file = "/etc/cron.d/myapp"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/cron.d/myapp');
    expect(content, contains('30 * * * * /usr/bin/newjob #my-job'));
    expect(content, isNot(contains('/usr/bin/oldjob')));
  });

  test('should remove entry from cron_file when absent', () async {
    await helper.createFile(
      '/etc/cron.d/myapp',
      '0 3 * * * /usr/bin/job1 #job1\n*/5 * * * * /usr/bin/job2 #job2\n',
    );

    final blocks = await helper.runConfig('''
      cron {
        name = "job1"
        job = "/usr/bin/job1"
        cron_file = "/etc/cron.d/myapp"
        status = "absent"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/cron.d/myapp');
    expect(content, isNot(contains('job1')));
    expect(content, contains('job2'));
  });

  test('should disable cron job when disabled=true', () async {
    final blocks = await helper.runConfig('''
      cron {
        name = "test-job"
        job = "/usr/bin/test"
        minute = "*/5"
        hour = "*"
        disabled = true
        cron_file = "/etc/cron.d/test"
      }
    ''');

    expect(blocks, hasLength(1));

    final content = await helper.readFile('/etc/cron.d/test');
    expect(content, contains('#*/5 * * * * /usr/bin/test #test-job'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      cron {
        name = "backup"
        job = "/usr/bin/backup"
        minute = "0"
        hour = "2"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('cron: backup (0 2 * * *)'));
  });
}
