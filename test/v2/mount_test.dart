import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse mount block properties', () async {
    final blocks = await helper.processConfig('''
      mount {
        path = "/mnt/data"
        src = "/dev/sdb1"
        fstype = "ext4"
        opts = "noatime,nodiratime"
        dump = 1
        passno = 2
        state = "present"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('mount'));
    expect(block.path, equals('/mnt/data'));
    expect(block.src, equals('/dev/sdb1'));
    expect(block.fstype, equals('ext4'));
    expect(block.opts, equals('noatime,nodiratime'));
    expect(block.dump, equals(1));
    expect(block.passno, equals(2));
    expect(block.state, equals('present'));
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      mount {
        path = "/mnt/data"
        src = "/dev/sdb1"
        fstype = "ext4"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.path, equals('/mnt/data'));
    expect(block.opts, equals('defaults'));
    expect(block.dump, equals(0));
    expect(block.passno, equals(0));
    expect(block.state, equals('present'));
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      mount {
        path = "/mnt/data"
        src = "/dev/sdb1"
        fstype = "ext4"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('mount: present /mnt/data (/dev/sdb1)'));
  });

  test('should return minimal dry-run summary', () async {
    final blocks = await helper.processConfig('''
      mount {}
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
