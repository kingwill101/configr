import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should parse sysctl block properties', () async {
    final blocks = await helper.processConfig('''
      sysctl {
        name = "net.ipv4.ip_forward"
        value = "1"
        reload = true
        ignore_errors = true
        sysctl_file = "/etc/sysctl.d/99-custom.conf"
        sysctl_set = true
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.blockType, equals('sysctl'));
    expect(block.name, equals('net.ipv4.ip_forward'));
    expect(block.value, equals('1'));
    expect(block.reload, isTrue);
    expect(block.ignoreErrors, isTrue);
    expect(block.sysctlFile, equals('/etc/sysctl.d/99-custom.conf'));
    expect(block.sysctlSet, isTrue);
  });

  test('should use default values', () async {
    final blocks = await helper.processConfig('''
      sysctl {
        name = "net.ipv4.ip_forward"
        value = "1"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first as dynamic;
    expect(block.name, equals('net.ipv4.ip_forward'));
    expect(block.value, equals('1'));
    expect(block.reload, isTrue);
    expect(block.ignoreErrors, isFalse);
    expect(block.sysctlFile, isEmpty);
    expect(block.sysctlSet, isFalse);
  });

  test('should return correct dry-run summary', () async {
    final blocks = await helper.processConfig('''
      sysctl {
        name = "net.ipv4.ip_forward"
        value = "1"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), equals('sysctl: net.ipv4.ip_forward=1'));
  });

  test('should return empty dry-run summary when no name', () async {
    final blocks = await helper.processConfig('''
      sysctl {
        value = "1"
      }
    ''');

    final block = blocks.first as dynamic;
    expect(block.dryRunSummary(), isEmpty);
  });
}
