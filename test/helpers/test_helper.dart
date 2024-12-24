import 'dart:io';

import 'package:configr/config_manager.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mockito/annotations.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_helper.mocks.dart';

@GenerateNiceMocks([MockSpec<PrivilegeEscalation>()])
class TestHelper {
  late FileSystem fileSystem;
  late PrivilegeEscalation privilegeEscalation;
  late ConfigManager configManager;

  final String baseDir;

  TestHelper([String path = "/test"]) : baseDir = path {
    setUp();
  }

  static void skipCi() {
    if (Platform.environment['GITHUB_ACTIONS'] == 'true') {
      markTestSkipped("Running inside GitHub Actions.");
    }
  }

  void setUp() {
    fileSystem = MemoryFileSystem();
    privilegeEscalation = MockPrivilegeEscalation();
    fileSystem.directory(baseDir).createSync(recursive: true);
    fileSystem.currentDirectory = fileSystem.directory(baseDir);

    configManager = ConfigManager(
        configPath: path.join(baseDir, 'config'),
        fileSystem: fileSystem,
        privilegeEscalation: privilegeEscalation);
  }

  String resolvePath(String relativePath) {
    if (path.isAbsolute(relativePath)) {
      return relativePath;
    }
    return path.join(baseDir, relativePath);
  }

  Future<void> createTestConfig(String content) async {
    final configFile = path.join(baseDir, 'config');
    await FileUtils.writeFile(configFile, content,
        recursive: true, fileSystem: fileSystem);
  }

  Future<void> createTestFile(String relativePath, String content) async {
    final absolutePath = resolvePath(
      relativePath,
    );
    await FileUtils.writeFile(absolutePath, content,
        recursive: true, fileSystem: fileSystem);
  }

  Future<void> verifyFileContent(
      String relativePath, String expectedContent) async {
    final absolutePath = resolvePath(relativePath);
    final exists =
        await FileUtils.fileExists(absolutePath, fileSystem: fileSystem);
    expect(exists, isTrue, reason: 'File $absolutePath should exist');

    final content =
        await FileUtils.readFile(absolutePath, fileSystem: fileSystem);
    expect(content, equals(expectedContent));
  }

  Future<void> verifyFilePermissions(String relativePath, int mode) async {
    final absolutePath = resolvePath(relativePath);
    final exists =
        await FileUtils.fileExists(absolutePath, fileSystem: fileSystem);
    expect(exists, isTrue, reason: 'File $absolutePath should exist');

    final currentMode = await FileUtils.getPermissions(absolutePath);
    expect(int.parse(currentMode, radix: 8), equals(mode));
  }

  Future<bool> fileExists(String relativePath) async {
    return FileUtils.fileExists(resolvePath(relativePath),
        fileSystem: fileSystem);
  }

  Future<bool> directoryExists(String relativePath) async {
    return FileUtils.directoryExists(resolvePath(relativePath),
        fileSystem: fileSystem);
  }

  Future<void> createDirectory(String relativePath) async {
    await FileUtils.createDirectory(resolvePath(relativePath),
        fileSystem: fileSystem, recursive: true);
  }

  Future<void> verifyFileOwnership(String relativePath,
      {String? owner, String? group}) async {
    final absolutePath = resolvePath(relativePath);
    final exists =
        await FileUtils.fileExists(absolutePath, fileSystem: fileSystem);
    expect(exists, isTrue, reason: 'File $absolutePath should exist');

    final ownership = await FileUtils.getOwnership(absolutePath);

    if (owner != null) {
      expect(ownership['owner'], equals(owner),
          reason: 'File owner should be $owner but was ${ownership['owner']}');
    }

    if (group != null) {
      expect(ownership['group'], equals(group),
          reason: 'File group should be $group but was ${ownership['group']}');
    }
  }

  Future<void> deleteTestFile(String filePath) async {
    await FileUtils.deleteFile(resolvePath(filePath), fileSystem: fileSystem);
  }
}
