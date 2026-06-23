import 'dart:io';

import 'package:testcontainers_core/testcontainers_core.dart';

/// Result of executing a command inside a container.
class ContainerProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  ContainerProcessResult(this.exitCode, this.stdout, this.stderr);
}

/// Helper for container-based integration tests.
///
/// Spins up a disposable Docker container for a given distro, mounts
/// the project source, and runs commands inside it to test system-level
/// operations (user creation, package management, hostname, etc.).
///
/// Usage:
/// ```dart
/// final helper = await ContainerTestHelper.start(
///   image: 'configr-test-ubuntu',
///   testEnv: 'ubuntu',
/// );
/// try {
///   final result = await helper.runDartTest(tags: 'debian');
///   expect(result.exitCode, 0);
/// } finally {
///   await helper.stop();
/// }
/// ```
class ContainerTestHelper {
  final DockerContainer _container;
  final String testEnv;

  ContainerTestHelper._(this._container, this.testEnv);

  /// Creates and starts a container from [image] with the project source
  /// mounted at `/app`.
  static Future<ContainerTestHelper> start({
    required String image,
    required String testEnv,
    List<String>? commandOverride,
  }) async {
    final container = DockerContainer(image)
        .withName('configr-test-$testEnv-${DateTime.now().millisecondsSinceEpoch}')
        .withEnv('CONFIGR_TEST_ENV', testEnv)
        .withVolumeMapping(
          Directory.current.path,
          '/app',
          'rw',
        )
        .withCommand(commandOverride ?? ['tail', '-f', '/dev/null'])
        .withKwargs({
          'CapAdd': ['SYS_ADMIN', 'NET_ADMIN'],
        });

    await container.start();
    return ContainerTestHelper._(container, testEnv);
  }

  /// Runs `dart pub get` inside the container.
  Future<void> pubGet() async {
    await _container.exec(['sh', '-c', 'cd /app && dart pub get']);
  }

  /// Runs `dart test` with optional [tags] filter.
  Future<ContainerProcessResult> runDartTest({
    String? tags,
    List<String>? testFiles,
  }) async {
    final args = <String>['sh', '-c', 'cd /app && dart test'];
    if (tags != null) {
      args.last = 'cd /app && dart test --tags $tags';
    }
    if (testFiles != null) {
      args.last = 'cd /app && dart test ${testFiles.join(' ')}';
    }
    return _runCommand(args);
  }

  /// Executes a command inside the container.
  Future<ContainerProcessResult> runCommand(List<String> command) async {
    return _runCommand(['sh', '-c', command.join(' ')]);
  }

  Future<ContainerProcessResult> _runCommand(List<String> command) async {
    final (exitCode, stdout) = await _container.exec(command);
    return ContainerProcessResult(
      exitCode,
      String.fromCharCodes(stdout),
      '',
    );
  }

  /// Copies a file or directory into the container.
  Future<void> copyInto(BytesTransferable transferable, String destination) async {
    await _container.copyIntoContainer(
      transferable,
      destination,
      0x1A4,
    );
  }

  /// Stops and removes the container.
  Future<void> stop() async {
    try {
      await _container.stop(force: true, deleteVolume: true);
    } catch (_) {}
  }

  /// Starts the container, runs [fn], and stops it afterwards.
  static Future<T> use<T>(
    String image,
    String testEnv,
    Future<T> Function(ContainerTestHelper) fn,
  ) async {
    final helper = await ContainerTestHelper.start(
      image: image,
      testEnv: testEnv,
    );
    try {
      return await fn(helper);
    } finally {
      await helper.stop();
    }
  }
}