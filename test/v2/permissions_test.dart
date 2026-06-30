import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with mode from config', () async {
    final blocks = await helper.processConfig('''
      permissions {
        source = "/test/file.txt"
        mode = "644"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('permissions'));
    expect((block as dynamic).mode, equals('644'));
    expect((block as dynamic).recursive, isFalse);
  });

  test('should set file ownership from config', () async {
    final blocks = await helper.processConfig('''
      permissions {
        source = "/test/file.txt"
        owner = "testuser"
        group = "testgroup"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).owner, equals('testuser'));
    expect((block as dynamic).group, equals('testgroup'));
    expect((block as dynamic).recursive, isFalse);
  });

  test('should handle recursive directory permissions config', () async {
    final blocks = await helper.processConfig('''
      permissions {
        source = "/test/recursive"
        mode = "755"
        recursive = true
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).recursive, isTrue);
    expect((block as dynamic).mode, equals('755'));
  });

  test('should support symbolic permission mode', () async {
    final blocks = await helper.processConfig('''
      permissions {
        source = "/test/file.txt"
        mode = "u+rw,g+r,o+r"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).mode, equals('u+rw,g+r,o+r'));
  });

  test('should support ACL configuration', () async {
    final blocks = await helper.processConfig('''
      permissions {
        source = "/test/file.txt"
        mode = "644"
        use_acl = true
        acl_entries = "user:testuser:rwx"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).mode, equals('644'));
  });
}
