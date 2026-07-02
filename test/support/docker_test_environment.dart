import 'dart:io';

/// Synchronous Docker preflight for tests that must decide `skip:` while the
/// suite is being declared.
class DockerTestEnvironment {
  const DockerTestEnvironment._();

  static final DockerAvailability docker = _probe(requireCompose: false);
  static final DockerAvailability dockerCompose = _probe(requireCompose: true);
  static final DockerAvailability dockerComposeAndBash = _probe(
    requireCompose: true,
    requireBash: true,
  );

  static DockerAvailability _probe({
    required bool requireCompose,
    bool requireBash = false,
  }) {
    final explicitSkip = _skipFromEnvironment();
    if (explicitSkip != null) {
      return DockerAvailability.unavailable(explicitSkip);
    }

    final dockerVersion = _run('docker', ['--version']);
    if (!dockerVersion.success) {
      return DockerAvailability.unavailable(
        'Docker-backed tests require the docker CLI: ${dockerVersion.summary}',
      );
    }

    final dockerInfo = _run('docker', ['info']);
    if (!dockerInfo.success) {
      return DockerAvailability.unavailable(
        'Docker-backed tests require a reachable Docker daemon: '
        '${dockerInfo.summary}',
      );
    }

    if (requireCompose) {
      final composeVersion = _run('docker', ['compose', 'version']);
      if (!composeVersion.success) {
        return DockerAvailability.unavailable(
          'Docker-backed tests require docker compose: '
          '${composeVersion.summary}',
        );
      }
    }

    if (requireBash) {
      final bashVersion = _run('bash', ['--version']);
      if (!bashVersion.success) {
        return DockerAvailability.unavailable(
          'Docker SSH integration tests require bash for local fixture setup: '
          '${bashVersion.summary}',
        );
      }
    }

    return const DockerAvailability.available();
  }

  static String? _skipFromEnvironment() {
    final value = Platform.environment['CONFIGR_SKIP_DOCKER_TESTS'];
    if (value == null || value.isEmpty || value == '0' || value == 'false') {
      return null;
    }
    return 'Docker-backed tests skipped by CONFIGR_SKIP_DOCKER_TESTS=$value';
  }

  static _CommandProbe _run(String executable, List<String> arguments) {
    try {
      final result = Process.runSync(executable, arguments);
      return _CommandProbe(
        executable,
        arguments,
        result.exitCode,
        result.stdout,
        result.stderr,
      );
    } on Object catch (error) {
      return _CommandProbe(executable, arguments, -1, '', error);
    }
  }
}

class DockerAvailability {
  final bool available;
  final String? reason;

  const DockerAvailability.available() : available = true, reason = null;

  const DockerAvailability.unavailable(this.reason) : available = false;

  Object get skip => available ? false : reason!;
}

class _CommandProbe {
  final String executable;
  final List<String> arguments;
  final int exitCode;
  final Object? stdout;
  final Object? stderr;

  _CommandProbe(
    this.executable,
    this.arguments,
    this.exitCode,
    this.stdout,
    this.stderr,
  );

  bool get success => exitCode == 0;

  String get summary {
    final output = [
      _stringify(stderr),
      _stringify(stdout),
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final command = ([executable, ...arguments]).join(' ');
    if (output.isEmpty) {
      return '$command exited with code $exitCode';
    }
    return '$command exited with code $exitCode: $output';
  }

  static String _stringify(Object? value) {
    if (value == null) return '';
    if (value is List<int>) return String.fromCharCodes(value).trim();
    return '$value'.trim();
  }
}
