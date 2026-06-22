import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  test('should initialize with default values', () async {
    final blocks = await helper.processConfig('''
      git {
        source = "https://github.com/test/repo.git"
        destination = "/tmp/test-repo"
      }
    ''');

    expect(blocks, hasLength(1));
    final block = blocks.first;
    expect(block.blockType, equals('git'));
    expect(block.source, equals('https://github.com/test/repo.git'));
    expect(block.destination, equals('/tmp/test-repo'));
  });

  test('should update state with configuration', () async {
    final blocks = await helper.processConfig('''
      git {
        source = "https://github.com/test/repo.git"
        destination = "/tmp/cloned-repo"
        branch = "develop"
        operation = "pull"
        commit_message = "Test commit"
      }
    ''');

    final block = blocks.first;
    expect((block as dynamic).branch, equals('develop'));
    expect((block as dynamic).operation, equals('pull'));
    expect((block as dynamic).commitMessage, equals('Test commit'));
  });
}
