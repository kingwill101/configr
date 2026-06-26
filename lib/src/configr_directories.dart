import 'package:configr/src/utils/fs.dart' show appDirs, fs;
import 'package:configr/src/utils/logging.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

/// Manages configr's directory structure for plugins, cache, backups, etc.
///
/// Resolution order (precedence):
/// 1. XDG directories (`~/.config/configr/`, `~/.cache/configr/`)
/// 2. Project-local `.configr/` directory (alongside the config file)
///
/// All subdirectories (plugins/, cache/, backups/) are auto-created on first
/// access via their respective getters, so consumers never need to mkdir-p.
class ConfigrDirectories {
  final String? projectConfigrPath;
  final FileSystem fileSystem;

  ConfigrDirectories({this.projectConfigrPath, FileSystem? fileSystem})
    : fileSystem = fileSystem ?? fs;

  // ---------------------------------------------------------------------------
  // XDG directories
  // ---------------------------------------------------------------------------

  /// XDG config home, e.g. `~/.config/configr/`.
  Directory get xdgConfigDir => fileSystem.directory(appDirs.config);

  /// XDG cache home, e.g. `~/.cache/configr/`.
  Directory get xdgCacheDir => fileSystem.directory(appDirs.cache);

  // ---------------------------------------------------------------------------
  // Project-local directories
  // ---------------------------------------------------------------------------

  /// Project-local `.configr/` directory, e.g. `/home/user/dotfiles/.configr/`.
  Directory? get projectDir => projectConfigrPath != null
      ? fileSystem.directory(projectConfigrPath!)
      : null;

  // ---------------------------------------------------------------------------
  // Plugin directories
  // ---------------------------------------------------------------------------

  /// Directories to scan for plugin manifests, in precedence order.
  ///
  /// Returns:
  /// 1. XDG config plugins dir (`~/.config/configr/plugins/`)
  /// 2. Project `.configr/plugins/` (if different from XDG)
  List<String> get pluginDirectories {
    final dirs = <String>[];

    final xdgPlugins = p.join(appDirs.config, 'plugins');
    dirs.add(xdgPlugins);

    if (projectConfigrPath != null) {
      final projectPlugins = p.join(projectConfigrPath!, 'plugins');
      if (projectPlugins != xdgPlugins) {
        dirs.add(projectPlugins);
      }
    }

    return dirs;
  }

  // ---------------------------------------------------------------------------
  // Cache directory
  // ---------------------------------------------------------------------------

  /// Primary cache directory (XDG cache home).
  ///
  /// Used by download blocks, template compilation, etc.
  String get cacheDir => appDirs.cache;

  // ---------------------------------------------------------------------------
  // Logs directory
  // ---------------------------------------------------------------------------

  /// Directory for log files.
  ///
  /// Returns project-local `.configr/logs/` if a project configr path is set,
  /// otherwise falls back to XDG `~/.config/configr/logs/`.
  String get logsDir {
    if (projectConfigrPath != null) {
      return p.join(projectConfigrPath!, 'logs');
    }
    return p.join(appDirs.config, 'logs');
  }

  // ---------------------------------------------------------------------------
  // Backup directory
  // ---------------------------------------------------------------------------

  /// Directory for backup storage used by backup blocks.
  String get backupDir => p.join(appDirs.cache, 'backups');

  // ---------------------------------------------------------------------------
  // Ensure directories exist
  // ---------------------------------------------------------------------------

  /// Ensures all standard subdirectories exist on disk.
  Future<void> ensureAll() async {
    final dirs = [
      xdgConfigDir,
      xdgCacheDir,
      fileSystem.directory(backupDir),
      // Project dir plugins/
      if (projectConfigrPath != null)
        fileSystem.directory(p.join(projectConfigrPath!, 'plugins')),
      if (projectConfigrPath != null)
        fileSystem.directory(p.join(projectConfigrPath!, 'cache')),
      fileSystem.directory(p.join(appDirs.config, 'logs')),
      if (projectConfigrPath != null)
        fileSystem.directory(p.join(projectConfigrPath!, 'logs')),
    ];

    for (final dir in dirs) {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        logger.debug('Created directory: ${dir.path}');
      }
    }
  }
}
