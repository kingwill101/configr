import 'package:test/test.dart';

import 'v2_test_helper.dart';

void main() {
  test('fail-fast halts processor after the first block error', () async {
    final helper = V2TestHelper();

    final blocks = await helper.runConfigFailFast('''
fail {
  msg = "stop here"
}

echo {
  message = "should not be processed"
}
''');

    expect(blocks.map((block) => block.blockType), equals(['fail']));
  });
}
