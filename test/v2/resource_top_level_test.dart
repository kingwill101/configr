import 'package:test/test.dart';

import 'v2_test_helper.dart';

/// Tests that `resource { ... }` works as a top-level block (not just
/// nested under `resources { ... }`).
void main() {
  test('resource block at top level parses and collects children', () async {
    final helper = V2TestHelper();
    final config = '''
resource {
  type "file"
  source = "/tmp/source"
  destination = "/tmp/dest"
  actions {
    copy {
      source = "/tmp/source/file.txt"
    }
  }
}
''';

    final blocks = await helper.processConfig(config);
    expect(blocks, hasLength(greaterThan(0)));
    // The copy block inside should be collected
    final copyBlocks = blocks.where((b) => b.blockType == 'copy').toList();
    expect(copyBlocks, hasLength(1));
    expect(copyBlocks[0].source, contains('/tmp/source/file.txt'));
  });

  test('resource block inside resources still works', () async {
    final helper = V2TestHelper();
    final config = '''
resources {
  resource {
    type "file"
    source = "/tmp/source"
    destination = "/tmp/dest"
    actions {
      copy {
        source = "/tmp/source/file.txt"
      }
    }
  }
}
''';

    final blocks = await helper.processConfig(config);
    expect(blocks, hasLength(greaterThan(0)));
    final copyBlocks = blocks.where((b) => b.blockType == 'copy').toList();
    expect(copyBlocks, hasLength(1));
    expect(copyBlocks[0].source, contains('/tmp/source/file.txt'));
  });
}
