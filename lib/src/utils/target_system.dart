import 'dart:io' show Platform;

import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/platform.dart'
    show OperatingSystem, OsFacts, OsFamily;
import 'package:configr/src/utils/shell_type.dart';

class TargetSystemFacts {
  final OperatingSystem os;
  final OsFamily family;
  final String distribution;
  final String distributionVersion;
  final String architecture;
  final String hostname;
  final String kernel;
  final String fqdn;
  final bool hasBash;
  final bool hasPowerShell;

  const TargetSystemFacts({
    required this.os,
    required this.family,
    required this.distribution,
    required this.distributionVersion,
    required this.architecture,
    required this.hostname,
    this.kernel = '',
    this.fqdn = '',
    this.hasBash = false,
    this.hasPowerShell = false,
  });

  bool get isLinux => os == OperatingSystem.linux;
  bool get isMacOS => os == OperatingSystem.macos;
}

class TargetSystemProbe {
  final ExecutionService executionService;

  const TargetSystemProbe(this.executionService);

  Future<TargetSystemFacts> detect() async {
    final os = await _detectOperatingSystem();
    final isLinux = os == OperatingSystem.linux;
    final isWindows = os == OperatingSystem.windows;

    final distribution = isLinux
        ? await _osReleaseValue('ID', fallback: 'linux')
        : os.name;
    final distributionVersion = isLinux
        ? await _osReleaseValue('VERSION_ID', fallback: '')
        : isWindows
        ? await _stdout('cmd', ['/c', 'ver'], fallback: '')
        : await _stdout('uname', ['-r'], fallback: '');
    final idLike = isLinux
        ? await _osReleaseValue('ID_LIKE', fallback: '')
        : '';

    final hasBash = isWindows
        ? false
        : await _checkCommand(ShellType.bash.defaultExecutable, '--version');
    final hasPowerShell = await _checkCommand(
      isWindows ? 'powershell' : 'pwsh',
      '--version',
    );

    return TargetSystemFacts(
      os: os,
      family: _detectFamily(os, distribution, idLike),
      distribution: distribution,
      distributionVersion: distributionVersion,
      architecture: isWindows
          ? await _stdout('powershell', [
              '-NoProfile',
              '-Command',
              r'(Get-CimInstance Win32_ComputerSystem).SystemType',
            ], fallback: _hostArch())
          : await _stdout('uname', ['-m'], fallback: _hostArch()),
      hostname: await _stdout('hostname', [], fallback: Platform.localHostname),
      kernel: isWindows
          ? distributionVersion
          : await _stdout('uname', ['-r'], fallback: ''),
      fqdn: isWindows
          ? await _stdout('powershell', [
              '-NoProfile',
              '-Command',
              r'[System.Net.Dns]::GetHostEntry("").HostName',
            ], fallback: Platform.localHostname)
          : await _stdout('hostname', ['-f'], fallback: Platform.localHostname),
      hasBash: hasBash,
      hasPowerShell: hasPowerShell,
    );
  }

  /// Detect the target operating system using multiple probes.
  ///
  /// First tries `uname -s` (available on Git Bash / MSYS2 / Cygwin / WSL).
  /// Then tries `cmd /c ver` (always available on native Windows OpenSSH).
  /// Finally tries PowerShell (reliable indicator of Windows).
  Future<OperatingSystem> _detectOperatingSystem() async {
    final uname = await _stdout('uname', ['-s']);
    if (uname.isNotEmpty) {
      final parsed = _parseOperatingSystem(uname);
      if (parsed != OperatingSystem.unknown) return parsed;
    }

    final ver = await _stdout('cmd', ['/c', 'ver']);
    if (ver.toLowerCase().contains('windows')) return OperatingSystem.windows;

    final psVer = await _stdout('powershell', [
      '-NoProfile',
      '-Command',
      r'$PSVersionTable.PSVersion',
    ]);
    if (psVer.isNotEmpty) return OperatingSystem.windows;

    return OperatingSystem.unknown;
  }

  Future<String> _osReleaseValue(
    String name, {
    required String fallback,
  }) async {
    return _stdout(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(
        '. /etc/os-release 2>/dev/null && printf "%s" "\${$name:-}"',
      ),
      fallback: fallback,
    );
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

  /// Check whether [command] is available on the target by running it with
  /// [versionArg] and checking for a zero exit code.
  Future<bool> _checkCommand(String command, String versionArg) async {
    try {
      final result = await executionService.run(command, [
        versionArg,
      ], runInShell: false);
      return result.exitCode == 0;
    } catch (_) {
      return false;
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
