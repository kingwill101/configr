@TestOn('linux')
library;

import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    final blocks = await helper.processConfig('''
      systemd {
        source = "my-service"
        operation = "enable"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('systemd'));
    expect((block as dynamic).operation, equals('enable'));
    expect((block as dynamic).serviceType, equals('service'));
    expect((block as dynamic).isUserService, isFalse);
  });

  test('should load configuration from properties', () async {
    final blocks = await helper.processConfig('''
      systemd {
        source = "my-service"
        operation = "start"
        service_type = "timer"
        user_service = true
        overwrite = true
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).operation, equals('start'));
    expect((block as dynamic).serviceType, equals('timer'));
    expect((block as dynamic).isUserService, isTrue);
  });
}
