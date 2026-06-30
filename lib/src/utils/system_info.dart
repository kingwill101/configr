import 'dart:io';

import 'package:i3config/i3config_v2.dart' as i3;

/// Collects system information and exposes it as i3config context variables.
///
/// OS and hardware details — host info, user information,
/// info, date/time, and environment variables — so config files can make
/// decisions based on the target machine.
class SystemInfo {
  // OS
  final String osName;
  final String osVersion;
  final String osArchitecture;
  final String osKernel;
  final String osDistribution;
  final String osDistributionVersion;
  final String osFamily;

  // Host
  final String hostHostname;
  final String hostFqdn;

  // User
  final String userName;
  final String userHome;
  final String userShell;

  // Date/time
  final DateTime now;

  // Environment (common vars only)
  final Map<String, String> env;

  // Configr info (set externally)
  final String configrVersion;
  final String configrCacheDir;
  final String configrBackupDir;

  // Config dir (set externally)
  final String configDir;

  SystemInfo({
    required this.configDir,
    this.configrVersion = '1.0.0',
    this.configrCacheDir = '',
    this.configrBackupDir = '',
  }) : osName = Platform.operatingSystem,
       osVersion = Platform.operatingSystemVersion,
       osArchitecture = _detectArchitecture(),
       osKernel = _extractKernel(Platform.operatingSystemVersion),
       osDistribution = _detectDistribution(),
       osDistributionVersion = _detectDistributionVersion(),
       osFamily = _detectFamily(
         Platform.operatingSystem,
         _detectDistribution(),
       ),
       hostHostname = Platform.localHostname,
       hostFqdn = _detectFqdn(),
       userName =
           Platform.environment['USER'] ??
           Platform.environment['USERNAME'] ??
           'unknown',
       userHome = Platform.environment['HOME'] ?? '/',
       userShell = Platform.environment['SHELL'] ?? '',
       now = DateTime.now(),
       env = _collectEnv();

  /// Sets all system info variables on the given [context].
  ///
  /// Each variable is set under **two** key forms because the i3config grammar
  /// splits `$os.name` into separate segments inside interpolated strings:
  ///
  /// | Form | Example | Works in |
  /// |------|---------|----------|
  /// | Flat underscore | `$os_name` | All positions (quoted, bare, assignment) |
  /// | Dotted | `$os.name` | `expandVariables` paths (Quoted, BareArg, command args) |
  ///
  /// **Prefer flat underscore names** — they are guaranteed to work everywhere.
  void applyToContext(i3.Context context) {
    // Existing / backwards-compatible
    context.setVariable('cwd', configDir);
    context.setVariable('configrCacheDir', configrCacheDir);
    context.setVariable('configrBackupDir', configrBackupDir);

    // OS — flat (primary) + dotted (secondary)
    _setBoth(context, 'os_name', 'os.name', osName);
    _setBoth(context, 'os_version', 'os.version', osVersion);
    _setBoth(context, 'os_architecture', 'os.architecture', osArchitecture);
    _setBoth(context, 'os_kernel', 'os.kernel', osKernel);
    _setBoth(context, 'os_distribution', 'os.distribution', osDistribution);
    _setBoth(
      context,
      'os_distribution_version',
      'os.distributionVersion',
      osDistributionVersion,
    );
    _setBoth(context, 'os_family', 'os.family', osFamily);

    // Host
    _setBoth(context, 'host_hostname', 'host.hostname', hostHostname);
    _setBoth(context, 'host_fqdn', 'host.fqdn', hostFqdn);

    // User
    _setBoth(context, 'user_username', 'user.username', userName);
    _setBoth(context, 'user_home', 'user.home', userHome);
    _setBoth(context, 'user_shell', 'user.shell', userShell);

    // Date/time
    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    _setBoth(context, 'date_year', 'date.year', y);
    _setBoth(context, 'date_month', 'date.month', mo);
    _setBoth(context, 'date_day', 'date.day', d);
    _setBoth(context, 'date_hour', 'date.hour', h);
    _setBoth(context, 'date_minute', 'date.minute', mi);
    _setBoth(context, 'date_second', 'date.second', s);
    _setBoth(
      context,
      'date_timestamp',
      'date.timestamp',
      now.toIso8601String(),
    );
    _setBoth(
      context,
      'date_epoch',
      'date.epoch',
      (now.millisecondsSinceEpoch ~/ 1000).toString(),
    );

    // Configr
    _setBoth(context, 'configr_version', 'configr.version', configrVersion);
    _setBoth(context, 'configr_cache_dir', 'configr.cacheDir', configrCacheDir);
    _setBoth(
      context,
      'configr_backup_dir',
      'configr.backupDir',
      configrBackupDir,
    );

    // Environment (common vars)
    for (final entry in env.entries) {
      _setBoth(context, 'env_${entry.key}', 'env.${entry.key}', entry.value);
    }
  }

  /// Sets [value] under both [flatKey] and [dottedKey] so users can use
  /// whichever form works in their context.
  static void _setBoth(
    i3.Context context,
    String flatKey,
    String dottedKey,
    String value,
  ) {
    context.setVariable(flatKey, value);
    context.setVariable(dottedKey, value);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static String _detectArchitecture() {
    try {
      final result = Process.runSync('uname', ['-m']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return Platform.version.contains('x64') ? 'x86_64' : 'unknown';
  }

  static String _extractKernel(String osVersion) {
    // osVersion is "Linux 7.0.10-1-MANJARO ..." on Linux
    // or "23.4.0" on macOS
    var v = osVersion;
    if (v.startsWith('Linux ')) v = v.substring(6);
    final parts = v.split('-');
    if (parts.isNotEmpty) return parts[0];
    return v;
  }

  static String _detectDistribution() {
    if (Platform.operatingSystem != 'linux') {
      return Platform.operatingSystem;
    }
    try {
      final result = Process.runSync('sh', [
        '-c',
        '. /etc/os-release 2>/dev/null && echo "\${ID:-unknown}"',
      ]);
      if (result.exitCode == 0) {
        final id = (result.stdout as String).trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  static String _detectDistributionVersion() {
    if (Platform.operatingSystem != 'linux') {
      return Platform.operatingSystemVersion;
    }
    try {
      final result = Process.runSync('sh', [
        '-c',
        '. /etc/os-release 2>/dev/null && echo "\${VERSION_ID:-}"',
      ]);
      if (result.exitCode == 0) {
        final id = (result.stdout as String).trim();
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    // Fallback: use `uname -r` (short kernel version) instead of the
    // verbose Platform.operatingSystemVersion that includes build metadata.
    try {
      final result = Process.runSync('uname', ['-r']);
      if (result.exitCode == 0) {
        final ver = (result.stdout as String).trim();
        if (ver.isNotEmpty) return ver;
      }
    } catch (_) {}
    return Platform.operatingSystemVersion;
  }

  static String _detectFamily(String os, String distribution) {
    switch (os) {
      case 'linux':
        // Check ID_LIKE from /etc/os-release for family detection
        try {
          final result = Process.runSync('sh', [
            '-c',
            '. /etc/os-release 2>/dev/null && echo "\${ID_LIKE:-}"',
          ]);
          if (result.exitCode == 0) {
            final like = (result.stdout as String).trim().toLowerCase();
            if (like.contains('debian')) return 'debian';
            if (like.contains('rhel') || like.contains('fedora'))
              return 'redhat';
            if (like.contains('arch')) return 'arch';
            if (like.contains('suse')) return 'suse';
            if (like.contains('alpine')) return 'alpine';
          }
        } catch (_) {}
        // Fallback: infer from distribution ID
        switch (distribution) {
          case 'debian' || 'ubuntu' || 'linuxmint' || 'pop' || 'elementary':
            return 'debian';
          case 'rhel' || 'centos' || 'fedora' || 'rocky' || 'almalinux':
            return 'redhat';
          case 'arch' || 'manjaro' || 'endeavouros':
            return 'arch';
          case 'opensuse' || 'suse':
            return 'suse';
          case 'alpine':
            return 'alpine';
          case 'nixos':
            return 'nixos';
          default:
            return distribution;
        }
      case 'macos':
        return 'darwin';
      case 'windows':
        return 'windows';
      default:
        return os;
    }
  }

  static String _detectFqdn() {
    try {
      final result = Process.runSync('hostname', ['-f']);
      if (result.exitCode == 0) {
        final fqdn = (result.stdout as String).trim();
        if (fqdn.isNotEmpty) return fqdn;
      }
    } catch (_) {}
    return Platform.localHostname;
  }

  static Map<String, String> _collectEnv() {
    const keys = [
      'HOME',
      'USER',
      'USERNAME',
      'SHELL',
      'TERM',
      'LANG',
      'PATH',
      'PWD',
      'EDITOR',
      'VISUAL',
      'XDG_CURRENT_DESKTOP',
      'DISPLAY',
      'WAYLAND_DISPLAY',
      'DBUS_SESSION_BUS_ADDRESS',
      'XDG_CONFIG_HOME',
      'XDG_DATA_HOME',
      'XDG_CACHE_HOME',
      'XDG_RUNTIME_DIR',
    ];
    final env = <String, String>{};
    for (final key in keys) {
      final val = Platform.environment[key];
      if (val != null && val.isNotEmpty) {
        env[key] = val;
      }
    }
    return env;
  }
}
