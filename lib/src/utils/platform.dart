import 'dart:io';

import 'package:configr/src/utils/shell_type.dart';

/// Operating system as detected by [Platform.operatingSystem].
///
/// Matches the strings returned by Dart's [Platform.operatingSystem]:
/// `linux`, `macos`, `windows`, `freebsd`, `openbsd`, `solaris`, etc.
enum OperatingSystem {
  linux,
  macos,
  windows,
  freebsd,
  openbsd,
  solaris,
  android,
  unknown;

  static OperatingSystem detect() {
    return switch (Platform.operatingSystem) {
      'linux' => OperatingSystem.linux,
      'macos' => OperatingSystem.macos,
      'windows' => OperatingSystem.windows,
      'freebsd' => OperatingSystem.freebsd,
      'openbsd' => OperatingSystem.openbsd,
      'solaris' => OperatingSystem.solaris,
      'android' => OperatingSystem.android,
      _ => OperatingSystem.unknown,
    };
  }
}

/// OS family grouping.
///
/// On Linux, the family is derived from the distribution
/// (e.g., `debian`, `redhat`, `arch`, `suse`, `alpine`).
/// Non-Linux OSes use their own family name (`darwin`, `freebsd`, etc.).
enum OsFamily {
  linuxGeneric,
  debian,
  redhat,
  arch,
  suse,
  alpine,
  darwin,
  freebsd,
  openbsd,
  solaris,
  windows,
  nixos,
  gentoo,
  unknown;

  bool get isLinuxFamily => switch (this) {
    linuxGeneric ||
    debian ||
    redhat ||
    arch ||
    suse ||
    alpine ||
    nixos ||
    gentoo => true,
    _ => false,
  };
}

/// Parsed OS information.
class OsFacts {
  final OperatingSystem os;
  final OsFamily family;
  final String distribution;
  final String distributionVersion;
  final String architecture;

  OsFacts({
    required this.os,
    required this.family,
    required this.distribution,
    required this.distributionVersion,
    required this.architecture,
  });

  factory OsFacts.detect() {
    final os = OperatingSystem.detect();
    final distribution = _detectDistribution(os);
    return OsFacts(
      os: os,
      family: _detectFamily(os, distribution),
      distribution: distribution,
      distributionVersion: _detectDistributionVersion(os),
      architecture: _detectArchitecture(),
    );
  }

  /// Returns true if this is any Linux variant.
  bool get isLinux => os == OperatingSystem.linux;

  /// Returns true if this is macOS.
  bool get isMacOS => os == OperatingSystem.macos;

  /// Returns true if this is any BSD variant.
  bool get isBsd =>
      os == OperatingSystem.freebsd || os == OperatingSystem.openbsd;

  /// Throws [UnsupportedError] if [os] is not [OperatingSystem.linux],
  /// with a message explaining which block is Linux-only.
  void requireLinux(String blockName) {
    if (os != OperatingSystem.linux) {
      throw UnsupportedError(
        '`$blockName` is currently only supported on Linux. '
        'Detected OS: ${Platform.operatingSystem}. '
        'macOS and FreeBSD support are planned.',
      );
    }
  }

  static String _detectDistribution(OperatingSystem os) {
    if (os != OperatingSystem.linux) {
      return Platform.operatingSystem;
    }
    try {
      final result = Process.runSync(
        ShellType.sh.defaultExecutable,
        ShellType.sh.scriptArgs(
          '. /etc/os-release 2>/dev/null && echo "\${ID:-unknown}"',
        ),
      );
      if (result.exitCode == 0) {
        final id = (result.stdout as String).trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  static String _detectDistributionVersion(OperatingSystem os) {
    if (os != OperatingSystem.linux) {
      return Platform.operatingSystemVersion;
    }
    try {
      final result = Process.runSync(
        ShellType.sh.defaultExecutable,
        ShellType.sh.scriptArgs(
          '. /etc/os-release 2>/dev/null && echo "\${VERSION_ID:-}"',
        ),
      );
      if (result.exitCode == 0) {
        final id = (result.stdout as String).trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    try {
      final result = Process.runSync('uname', ['-r']);
      if (result.exitCode == 0) {
        final ver = (result.stdout as String).trim();
        if (ver.isNotEmpty) return ver;
      }
    } catch (_) {}
    return Platform.operatingSystemVersion;
  }

  static OsFamily _detectFamily(OperatingSystem os, String distribution) {
    switch (os) {
      case OperatingSystem.linux:
        try {
          final result = Process.runSync(
            ShellType.sh.defaultExecutable,
            ShellType.sh.scriptArgs(
              '. /etc/os-release 2>/dev/null && echo "\${ID_LIKE:-}"',
            ),
          );
          if (result.exitCode == 0) {
            final like = (result.stdout as String).trim().toLowerCase();
            if (like.contains('debian')) return OsFamily.debian;
            if (like.contains('rhel') || like.contains('fedora')) {
              return OsFamily.redhat;
            }
            if (like.contains('arch')) return OsFamily.arch;
            if (like.contains('suse')) return OsFamily.suse;
            if (like.contains('alpine')) return OsFamily.alpine;
          }
        } catch (_) {}
        switch (distribution) {
          case 'debian' || 'ubuntu' || 'linuxmint' || 'pop' || 'elementary':
            return OsFamily.debian;
          case 'rhel' || 'centos' || 'fedora' || 'rocky' || 'almalinux':
            return OsFamily.redhat;
          case 'arch' || 'manjaro' || 'endeavouros':
            return OsFamily.arch;
          case 'opensuse' || 'suse':
            return OsFamily.suse;
          case 'alpine':
            return OsFamily.alpine;
          case 'nixos':
            return OsFamily.nixos;
          case 'gentoo' || 'funtoo':
            return OsFamily.gentoo;
          default:
            return OsFamily.linuxGeneric;
        }
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

  static String _detectArchitecture() {
    try {
      final result = Process.runSync('uname', ['-m']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return Platform.version.contains('x64') ? 'x86_64' : 'unknown';
  }
}
