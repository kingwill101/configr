import 'dart:io';

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
}
