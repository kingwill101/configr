import 'package:test/test.dart';
import 'package:configr/src/modules/resource/echo.dart';
import 'package:configr/src/models/action.dart';

import '../../helpers/test_helper.dart';

void main() {
  late TestHelper helper;

  setUp(() {
    helper = TestHelper();
  });

  test('should echo message with default settings', () async {
    final resourceModel = helper.createTestResource(
        source: 'test',
        destination: 'test',
        actions: [
          Action(type: 'echo', properties: {'message': 'Hello World'})
        ]);

    final module = FileEchoModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    await module();

    // Verify default settings
    expect(module.message, equals('Hello World'));
    expect(module.color, isTrue);
    expect(module.verbose, isFalse);
    expect(module.level, equals('info'));
  });

  test('should echo message with custom settings', () async {
    final resourceModel = helper.createTestResource(
        source: 'test',
        destination: 'test',
        actions: [
          Action(type: 'echo', properties: {
            'message': 'Warning Message',
            'color': false,
            'verbose': true,
            'level': 'warning'
          })
        ]);

    final module = FileEchoModule(resourceModel, resourceModel.actions.first,
        fileSystem: helper.fileSystem);

    await module();

    // Verify custom settings
    expect(module.message, equals('Warning Message'));
    expect(module.color, isFalse);
    expect(module.verbose, isTrue);
    expect(module.level, equals('warning'));
  });
}
