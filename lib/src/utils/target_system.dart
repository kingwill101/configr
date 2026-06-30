import 'dart:io' show Platform;

import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/platform.dart'
    show OperatingSystem, OsFacts, OsFamily;

class TargetSystemFacts {
  final OperatingSystem os;
  final OsFamily family;
  final String distribution;
  final String distributionVersion;
  final String architecture;
  final String hostname;

  const TargetSystemFacts({
    required this.os,
    required this.family,
    required this.distribution,
    required this.distributionVersion,
    required this.architecture,
    required this.hostname,
  });

  bool get isLinux => os == OperatingSystem.linux;
  bool get isMacOS => os == OperatingSystem.macos;
}

class TargetSystemProbe {
  final ExecutionService executionService;

  const TargetSystemProbe(this.executionService);

  Future<TargetSystemFacts> detect() async {
    final system = await _stdout('uname', ['-s']);
    final os = _parseOperatingSystem(system);
    final distribution = os == OperatingSystem.linux
        ? await _osReleaseValue('ID', fallback: 'linux')
        : os.name;
    final distributionVersion = os == OperatingSystem.linux
        ? await _osReleaseValue('VERSION_ID', fallback: '')
        : await _stdout('uname', ['-r']);
    final idLike = os == OperatingSystem.linux
        ? await _osReleaseValue('ID_LIKE', fallback: '')
        : '';

    return TargetSystemFacts(
      os: os,
      family: _detectFamily(os, distribution, idLike),
      distribution: distribution,
      distributionVersion: distributionVersion,
      architecture: await _stdout('uname', ['-m'], fallback: _hostArch()),
      hostname: await _stdout('hostname', [], fallback: Platform.localHostname),
    );
  }

  Future<String> _osReleaseValue(
    String name, {
    required String fallback,
  }) async {
    return _stdout('sh', [
      '-c',
      '. /etc/os-release 2>/dev/null && printf "%s" "\${$name:-}"',
    ], fallback: fallback);
  }

  Future<String> _stdout(
    String command,
    List<String> args, {
    String fallback = '',
  }) async {
    try {
      final result = await executionService.run(
        command,
        args,
        runInShell: false,
      );
      if (result.exitCode == 0) {
        final value = result.stdout.toString().trim();
        if (value.isNotEmpty) return value;
      }
    } catch (_) {}
    return fallback;
  }

  static OperatingSystem _parseOperatingSystem(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('linux')) return OperatingSystem.linux;
    if (lower.contains('darwin')) return OperatingSystem.macos;
    if (lower.contains('freebsd')) return OperatingSystem.freebsd;
    if (lower.contains('openbsd')) return OperatingSystem.openbsd;
    if (lower.contains('sunos') || lower.contains('solaris')) {
      return OperatingSystem.solaris;
    }
    if (lower.contains('mingw') || lower.contains('windows')) {
      return OperatingSystem.windows;
    }
    return OperatingSystem.unknown;
  }

  static OsFamily _detectFamily(
    OperatingSystem os,
    String distribution,
    String idLike,
  ) {
    switch (os) {
      case OperatingSystem.linux:
        final like = idLike.toLowerCase();
        if (like.contains('debian')) return OsFamily.debian;
        if (like.contains('rhel') || like.contains('fedora')) {
          return OsFamily.redhat;
        }
        if (like.contains('arch')) return OsFamily.arch;
        if (like.contains('suse')) return OsFamily.suse;
        if (like.contains('alpine')) return OsFamily.alpine;

        return switch (distribution) {
          'debian' ||
          'ubuntu' ||
          'linuxmint' ||
          'pop' ||
          'elementary' => OsFamily.debian,
          'rhel' ||
          'centos' ||
          'fedora' ||
          'rocky' ||
          'almalinux' => OsFamily.redhat,
          'arch' || 'manjaro' || 'endeavouros' => OsFamily.arch,
          'opensuse' || 'suse' => OsFamily.suse,
          'alpine' => OsFamily.alpine,
          'nixos' => OsFamily.nixos,
          'gentoo' || 'funtoo' => OsFamily.gentoo,
          _ => OsFamily.linuxGeneric,
        };
      case OperatingSystem.macos:
        return OsFamily.darwin;
      case OperatingSystem.windows:
        return OsFamily.windows;
      case OperatingSystem.freebsd:
        return OsFamily.freebsd;
      case OperatingSystem.openbsd:
        return OsFamily.openbsd;
      case OperatingSystem.solaris:
        return OsFamily.solaris;
      default:
        return OsFamily.unknown;
    }
  }

  static String _hostArch() =>
      Platform.version.contains('x64') ? 'x86_64' : 'unknown';
}

extension TargetSystemFactsOsFacts on TargetSystemFacts {
  OsFacts toOsFacts() {
    return OsFacts(
      os: os,
      family: family,
      distribution: distribution,
      distributionVersion: distributionVersion,
      architecture: architecture,
    );
  }
}
