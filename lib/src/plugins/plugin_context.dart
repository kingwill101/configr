import 'dart:io';

import 'package:i3config/i3config_v2.dart' as i3;

class PluginContext {
  final Map<String, dynamic> _data;

  PluginContext._(this._data);

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(_data);

  static PluginContext create({String? configrVersion}) {
    final commonEnvVars = [
      'HOME',
      'USER',
      'USERNAME',
      'SHELL',
      'TERM',
      'LANG',
      'PATH',
      'PWD',
      'EDITOR',
      'XDG_CURRENT_DESKTOP',
      'DISPLAY',
      'WAYLAND_DISPLAY',
      'DBUS_SESSION_BUS_ADDRESS',
    ];

    final env = <String, String>{};
    for (final key in commonEnvVars) {
      final val = Platform.environment[key];
      if (val != null && val.isNotEmpty) {
        env[key] = val;
      }
    }

    final data = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'architecture': _detectArchitecture(),
      'hostname': Platform.localHostname,
      'os': {
        'name': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      },
      'user': {
        'username':
            Platform.environment['USER'] ??
            Platform.environment['USERNAME'] ??
            'unknown',
        'home': Platform.environment['HOME'] ?? '/',
        'shell': Platform.environment['SHELL'] ?? '',
      },
      'env': env,
      'configr': {
        'version': configrVersion ?? '1.0.0',
        'cacheDir': '',
        'backupDir': '',
      },
    };

    return PluginContext._(data);
  }

  static PluginContext fromConfigContext(
    i3.Context context, {
    String? configrVersion,
  }) {
    final fallback = create(configrVersion: configrVersion).toMap();
    final env = <String, String>{};
    for (final entry in context.variables.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.startsWith('env_') && value != null) {
        env[key.substring(4)] = value.toString();
      }
    }

    final platform = _contextString(context, 'os_name') ?? fallback['platform'];
    final architecture =
        _contextString(context, 'os_architecture') ?? fallback['architecture'];
    final hostname =
        _contextString(context, 'host_hostname') ?? fallback['hostname'];
    final version =
        _contextString(context, 'os_version') ??
        (fallback['os'] as Map)['version'];
    final username =
        _contextString(context, 'user_username') ??
        (fallback['user'] as Map)['username'];
    final home =
        _contextString(context, 'user_home') ??
        (fallback['user'] as Map)['home'];
    final shell =
        _contextString(context, 'user_shell') ??
        (fallback['user'] as Map)['shell'];

    return PluginContext._({
      'platform': platform,
      'architecture': architecture,
      'hostname': hostname,
      'os': {
        'name': platform,
        'version': version,
        'family': _contextString(context, 'os_family') ?? '',
        'distribution': _contextString(context, 'os_distribution') ?? '',
        'distributionVersion':
            _contextString(context, 'os_distribution_version') ?? '',
        'kernel': _contextString(context, 'os_kernel') ?? '',
      },
      'user': {'username': username, 'home': home, 'shell': shell},
      'env': env.isEmpty ? fallback['env'] : env,
      'configr': {
        'version':
            configrVersion ??
            _contextString(context, 'configr_version') ??
            (fallback['configr'] as Map)['version'],
        'cacheDir':
            _contextString(context, 'configr_cache_dir') ??
            (fallback['configr'] as Map)['cacheDir'],
        'backupDir':
            _contextString(context, 'configr_backup_dir') ??
            (fallback['configr'] as Map)['backupDir'],
      },
    });
  }

  PluginContext withConfigrDirs({
    required String cacheDir,
    required String backupDir,
  }) {
    _data['configr'] = {
      'version': _data['configr']['version'],
      'cacheDir': cacheDir,
      'backupDir': backupDir,
    };
    return this;
  }

  PluginContext withVersion(String version) {
    _data['configr'] = {..._data['configr'] as Map, 'version': version};
    return this;
  }

  static String _detectArchitecture() {
    final os = Platform.operatingSystem;
    if (os == 'linux' || os == 'macos') {
      try {
        final result = Process.runSync('uname', ['-m']);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim();
        }
      } catch (_) {}
    }
    return Platform.version.contains('x64') ? 'x86_64' : 'unknown';
  }

  static String? _contextString(i3.Context context, String key) {
    final value = context.getVariable(key);
    if (value == null) return null;
    final string = value.toString();
    return string.isEmpty ? null : string;
  }
}
