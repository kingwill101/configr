@TestOn('vm')
@Tags(['container'])
library;

import 'package:test/test.dart';

import 'container_test_helper.dart';
import 'container_test_runner.dart';

void main() {
  group('apt block integration (container-backed)', () {
    ContainerTestHelper? container;

    setUpAll(() async {
      container = await ContainerTestHelper.start(
        image: 'testing-ubuntu-test',
        testEnv: 'ubuntu',
      );
      final pubGetResult = await container!.runCommand(
        'cd /app && dart pub get 2>&1',
      );
      expect(
        pubGetResult.exitCode,
        0,
        reason: 'dart pub get failed: ${pubGetResult.stdout}',
      );

      final aptUpdateResult = await container!.runCommand(
        'apt-get update -qq 2>&1',
      );
      expect(
        aptUpdateResult.exitCode,
        0,
        reason: 'apt-get update failed: ${aptUpdateResult.stdout}',
      );
    });

    tearDownAll(() async {
      await container?.stop();
    });

    test(
      'configr apply installs hello package via apt block',
      () async {
        // Write config file inside the container
        const configContent = '''
apt {
  source = "hello"
  operation = "install"
  update_cache = false
  skip_if_installed = false
}
''';
        await container!.runCommand(
          'cat > /tmp/test_apt_install.i3 << "EOF"\n$configContent\nEOF',
        );

        try {
          final result = await container!.runCommand(
            'cd /app && dart run bin/configr.dart apply --v2 '
            '--config /tmp/test_apt_install.i3 2>&1',
          );

          expect(
            result.exitCode,
            0,
            reason: 'configr apply failed: ${result.stdout}',
          );
          expect(
            result.stdout,
            contains('hello'),
            reason: 'Should mention hello in output: ${result.stdout}',
          );

          // Verify package is actually installed
          final dpkgResult = await container!.runCommand('dpkg -s hello 2>&1');
          expect(
            dpkgResult.exitCode,
            0,
            reason: 'hello should be installed: ${dpkgResult.stdout}',
          );

          final whichResult = await container!.runCommand('which hello 2>&1');
          expect(
            whichResult.exitCode,
            0,
            reason: 'hello binary should exist: ${whichResult.stdout}',
          );
        } finally {
          await container!.runCommand('apt-get remove -y hello 2>&1');
          await container!.runCommand('rm -f /tmp/test_apt_install.i3');
        }
      },
      tags: debianTag,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'configr apply uninstalls hello package via apt block',
      () async {
        await container!.runCommand('apt-get install -y hello 2>&1');

        const configContent = '''
apt {
  source = "hello"
  operation = "uninstall"
  update_cache = false
}
''';
        await container!.runCommand(
          'cat > /tmp/test_apt_uninstall.i3 << "EOF"\n$configContent\nEOF',
        );

        try {
          final result = await container!.runCommand(
            'cd /app && dart run bin/configr.dart apply --v2 '
            '--config /tmp/test_apt_uninstall.i3 2>&1',
          );

          expect(
            result.exitCode,
            0,
            reason: 'configr apply failed: ${result.stdout}',
          );

          final whichResult = await container!.runCommand(
            'which hello 2>&1 || true',
          );
          expect(
            whichResult.stdout,
            isEmpty,
            reason: 'hello should be uninstalled',
          );
        } finally {
          await container!.runCommand('rm -f /tmp/test_apt_uninstall.i3');
        }
      },
      tags: debianTag,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'configr apply reports error for non-existent package',
      () async {
        const configContent = '''
apt {
  source = "this-package-definitely-does-not-exist-42"
  operation = "install"
  update_cache = false
  skip_if_installed = false
}
''';
        await container!.runCommand(
          'cat > /tmp/test_apt_fail.i3 << "EOF"\n$configContent\nEOF',
        );

        try {
          final result = await container!.runCommand(
            'cd /app && dart run bin/configr.dart apply --v2 '
            '--config /tmp/test_apt_fail.i3 2>&1',
          );

          expect(
            result.exitCode,
            isNot(0),
            reason: 'Should fail for non-existent package',
          );
          expect(
            result.stdout,
            contains('Unable to locate package'),
            reason:
                'Should mention package not found in stdout: ${result.stdout}',
          );
        } finally {
          await container!.runCommand('rm -f /tmp/test_apt_fail.i3');
        }
      },
      tags: debianTag,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
