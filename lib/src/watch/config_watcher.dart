import 'dart:async';
import 'dart:io' as io;

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/configr_runtime.dart';
import 'package:configr/src/utils/logging.dart';

/// File watcher for configr configuration files.
///
/// Watches the main config file and any included files discovered by the
/// i3config include handler.  Change events are debounced to avoid
/// overlapping applies.
class ConfigWatcher {
  final ConfigrRuntime runtime;
  final Duration debounceDuration;
  final void Function(String message) onStatus;
  final void Function(String message) onError;

  StreamSubscription<io.FileSystemEvent>? _subscription;
  Timer? _debounceTimer;
  bool _isRunning = false;

  /// The currently known set of watched file paths.
  final Set<String> _watchedPaths = {};

  ConfigWatcher({
    required this.runtime,
    this.debounceDuration = const Duration(milliseconds: 500),
    required this.onStatus,
    required this.onError,
  });

  /// Whether the watcher is actively monitoring.
  bool get isRunning => _isRunning;

  /// Start watching the configuration file.
  Future<void> start() async {
    if (_isRunning) return;

    final configPath = runtime.resolvedConfigPath;
    final file = io.File(configPath);

    if (!await file.exists()) {
      onError('Configuration file not found: $configPath');
      return;
    }

    // Parse and collect initial block metadata to know what "included" files
    // exist.  We don't execute anything here — just discover.
    try {
      final blocks = await runtime.parseAndCollect();
      _discoverIncludedFiles(blocks);
    } catch (e) {
      logger.info('Initial parse for file discovery skipped: $e');
    }

    _watchedPaths.add(configPath);
    _isRunning = true;

    // Start watching each path.  We use a single recursive watch on the
    // directory containing the config file, plus individual watches for
    // any explicitly included files in other directories.
    final dir = file.parent;
    _subscription = dir
        .watch(events: io.FileSystemEvent.all)
        .listen(
          _onFileEvent,
          onError: (Object error) {
            onError('File watch error: $error');
          },
        );

    for (final path in _watchedPaths) {
      if (path != configPath) {
        final f = io.File(path);
        if (await f.exists()) {
          f.parent
              .watch(events: io.FileSystemEvent.all)
              .listen(
                _onFileEvent,
                onError: (Object error) {
                  onError('File watch error for $path: $error');
                },
              );
        }
      }
    }

    onStatus('Watching configuration files...');
  }

  /// Stop watching.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _watchedPaths.clear();
    onStatus('File watching stopped.');
  }

  /// Handles a raw file system event — debounces and triggers apply.
  void _onFileEvent(io.FileSystemEvent event) {
    if (!_isRunning) return;

    final path = event.path;

    // Only react to changes in .i3, .conf, or extensionless config files,
    // and only to modify/create/delete events.
    if (!_isConfigFile(path)) return;
    // Skip access/modify events — only process content changes.
    if (event.type == io.FileSystemEvent.modify) return;

    logger.debug('File change detected: $path (${event.type})');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, _applyChanges);
  }

  /// Apply the debounced changes — re-read config and re-apply.
  Future<void> _applyChanges() async {
    if (!_isRunning) return;

    onStatus('Configuration file changed, re-applying...');

    try {
      await runtime.apply();
      onStatus('Configuration re-applied successfully.');
    } catch (e) {
      onError('Failed to re-apply configuration: $e');
    }
  }

  /// Scan parsed blocks for included/sub-config files and add them to
  /// the watched file set.
  void _discoverIncludedFiles(List<BlockSnapshot> blocks) {
    for (final snapshot in blocks) {
      final source = snapshot.source;
      if (source.isNotEmpty && !_watchedPaths.contains(source)) {
        final resolved = _resolvePath(source);
        if (resolved != null) {
          _watchedPaths.add(resolved);
        }
      }

      // Check for explicit include references in properties
      final includeProps = snapshot.properties['includes'];
      if (includeProps is List) {
        for (final inc in includeProps) {
          final resolved = _resolvePath(inc.toString());
          if (resolved != null) {
            _watchedPaths.add(resolved);
          }
        }
      } else if (includeProps is String && includeProps.isNotEmpty) {
        final resolved = _resolvePath(includeProps);
        if (resolved != null) {
          _watchedPaths.add(resolved);
        }
      }
    }
  }

  /// Resolve a possibly-relative path against the working directory.
  String? _resolvePath(String path) {
    if (path.startsWith('/')) return path;
    try {
      return '${runtime.workingDirectory}/$path';
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [path] looks like a configr/i3 config file.
  bool _isConfigFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.i3') ||
        lower.endsWith('.conf') ||
        // Extensionless files — match basenames like 'config'
        (!lower.contains('.') && path.contains(RegExp(r'config$')));
  }
}
