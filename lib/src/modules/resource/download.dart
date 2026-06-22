import 'dart:convert';
import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/extensions/string.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Enhanced file download module with resume capability, authentication, and integrity verification.
/// 
/// Features:
/// - Resume interrupted downloads from last position
/// - HTTP authentication (Basic, Bearer, API keys)
/// - Multiple checksum algorithms (SHA-256, MD5, SHA-1)
/// - Progress tracking with detailed statistics
/// - Comprehensive event emission
/// - Rollback support
class FileDownloadModule extends ResourceModule {
  bool get destinationFileExisted =>
      state['destinationFileExisted'] as bool? ?? false;

  String? get originalContent => state['originalContent'] as String?;

  String get sourceUrl => state['sourceUrl'] as String? ?? '';

  bool get overwrite => state['overwrite'] as bool? ?? false;

  String? get expectedChecksum => state['expectedChecksum'] as String?;

  String? get actualChecksum => state['actualChecksum'] as String?;

  int get receivedBytes => state['receivedBytes'] as int? ?? 0;

  int get totalBytes => state['totalBytes'] as int? ?? -1;

  // Enhanced features
  bool get resumeEnabled => state['resumeEnabled'] as bool? ?? false;
  String? get authType => state['authType'] as String?;
  String? get authToken => state['authToken'] as String?;
  String? get username => state['username'] as String?;
  String? get password => state['password'] as String?;
  String get checksumAlgorithm => state['checksumAlgorithm'] as String? ?? 'sha256';
  int get downloadSpeed => state['downloadSpeed'] as int? ?? 0; // bytes per second
  Duration get downloadDuration => Duration(milliseconds: state['downloadDuration'] as int? ?? 0);
  bool get isResumed => state['isResumed'] as bool? ?? false;
  int get resumePosition => state['resumePosition'] as int? ?? 0;

FileDownloadModule(super.file, super.action,
      {super.allowedActions = const ['download'], super.fileSystem, super.eventBus}) {
    updateState({
      'destinationFileExisted': false,
      'originalContent': null,
      'sourceUrl': '',
      'overwrite': false,
      'receivedBytes': 0,
      'totalBytes': -1,
      'resumeEnabled': false,
      'authType': null,
      'authToken': null,
      'username': null,
      'password': null,
      'checksumAlgorithm': 'sha256',
      'downloadSpeed': 0,
      'downloadDuration': 0,
      'isResumed': false,
      'resumePosition': 0,
    });
  }

  Future<String> _downloadWithProgress(
      String url, String destinationPath) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      
      // Add authentication headers
      _addAuthenticationHeaders(request);
      
      // Add resume headers if enabled
      int resumePosition = 0;
      if (resumeEnabled) {
        final file = (fileSystem ?? fs).file(destinationPath);
        if (await file.exists()) {
          resumePosition = await file.length();
          request.headers['Range'] = 'bytes=$resumePosition-';
          updateState({'resumePosition': resumePosition, 'isResumed': true});
        }
      }
      
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        emitEvent(FailedEvent(
            message: 'Failed to download file: ${response.statusCode}',
            moduleId: action.id));
        throw ActionFailedException(
          'Failed to download file: ${response.statusCode}',
          moduleId: action.id,
        );
      }

      updateState(
          {'totalBytes': response.contentLength ?? -1, 'receivedBytes': 0});

      await Future.delayed(Duration(milliseconds: 100), () {});

      emitEvent(StartedEvent(
          message: 'Starting download from $url', moduleId: action.id));

      final file = (fileSystem ?? fs).file(destinationPath);
      final sink = file.openWrite(mode: isResumed ? FileMode.append : FileMode.write);

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          updateState({'receivedBytes': receivedBytes + chunk.length});

          emitEvent(DownloadProgressEvent(
              current: receivedBytes,
              total: totalBytes,
              message: isResumed ? 'Resuming download...' : 'Downloading...',
              moduleId: action.id));
        }
      } finally {
        await sink.close();
      }

      final hash = _calculateChecksum(await file.readAsBytes(), checksumAlgorithm);
      updateState({'actualChecksum': hash});

      emitEvent(StatusUpdateEvent(
          level: StatusEvent.info,
          message: 'Download complete. SHA-256: $hash',
          moduleId: action.id));

      return hash;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> execute() async {
    final sourceUrlValue = source.unquote();
    final destinationPath = destination;

    // Parse configuration
    final config = _parseConfiguration();
    updateState({
      'sourceUrl': sourceUrlValue,
      ...config,
    });

    await executeModules();
    if (isRollingBack) return;

    final exists =
        await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);
    updateState({'destinationFileExisted': exists});

    if (exists && overwrite == false) {
      emitEvent(FailedEvent(
          message: 'Destination already exists: $destinationPath',
          moduleId: action.id));
      throw DestinationExistsException(destinationPath);
    }

    if (exists) {
      if (overwrite) {
        emitEvent(StatusUpdateEvent(
            level: StatusEvent.info,
            message: 'Deleting existing file $destinationPath',
            moduleId: action.id));
        await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
      } else {
        final content =
            await FileUtils.readFile(destinationPath, fileSystem: fileSystem);
        updateState({'originalContent': content});
      }
    }

    emitEvent(StatusUpdateEvent(
        level: StatusEvent.info,
        message: 'Downloading file from $sourceUrl to $destinationPath',
        moduleId: action.id));

    try {
      final startTime = DateTime.now();
      final checksum = await _downloadWithProgress(sourceUrl, destinationPath);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      updateState({
        'downloadDuration': duration.inMilliseconds,
        'downloadSpeed': duration.inMilliseconds > 0 ? (receivedBytes * 1000 / duration.inMilliseconds).round() : 0,
      });

      if (action.properties['checksum'] != null) {
        updateState({'expectedChecksum': action.properties['checksum']});

        if (checksum != expectedChecksum) {
          await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
          emitEvent(FailedEvent(
              message:
                  'Checksum validation failed: Expected $expectedChecksum, got $checksum',
              moduleId: action.id));
          throw ActionFailedException(
            'Checksum validation failed: Expected $expectedChecksum, got $checksum',
            moduleId: action.id,
          );
        }

        emitEvent(StatusUpdateEvent(
            level: StatusEvent.info,
            message: 'Checksum verification passed ($checksumAlgorithm)',
            moduleId: action.id));
      }

      updateState({'downloadCompleted': true});
      action.sha256 = await computeInitialStateHash();
      action.status = 'completed';
      action.timestamp = DateTime.now().toIso8601String();
      await saveState();
    } catch (e, st) {
      updateState({'error': e.toString(), 'stackTrace': st.toString()});
      emitEvent(FailedEvent(
          message: 'Download failed: ${e.toString()}', moduleId: action.id));
      throw ActionFailedException('Error downloading file: $e');
    }
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(
      moduleId: action.id,
      message: 'Rolling back download operation for $destination',
    ));
    
    await super.rollback();
    try {
      if (destinationFileExisted) {
        if (originalContent != null) {
          emitEvent(StatusUpdateEvent(
              level: StatusEvent.info,
              message: 'Restoring original content to $destination',
              moduleId: action.id));
          await FileUtils.writeFile(destination, originalContent!,
              fileSystem: fileSystem);
        }
      } else {
        emitEvent(StatusUpdateEvent(
            level: StatusEvent.info,
            message: 'Removing downloaded file $destination (rollback)',
            moduleId: action.id));
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }
      
      emitEvent(CompletedEvent(
        moduleId: action.id,
        message: 'Download rollback completed for $destination',
      ));
      
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState(
          {'rollbackError': e.toString(), 'rollbackStackTrace': st.toString()});
      emitEvent(FailedEvent(
          message: 'Rollback failed: ${e.toString()}', moduleId: action.id));
      rethrow;
    }
    await saveState();
  }

  /// Parse configuration from action properties.
  /// 
  /// Extracts authentication settings, resume configuration, checksum algorithm,
  /// and other configuration options from the action properties.
  Map<String, dynamic> _parseConfiguration() {
    return {
      'overwrite': action.properties.containsKey('overwrite') && action.properties['overwrite'] == true,
      'resumeEnabled': action.properties['resume'] == 'true',
      'authType': action.properties['auth_type'],
      'authToken': action.properties['auth_token'],
      'username': action.properties['username'],
      'password': action.properties['password'],
      'checksumAlgorithm': action.properties['checksum_algorithm'] ?? 'sha256',
    };
  }

  /// Add authentication headers to the HTTP request.
  void _addAuthenticationHeaders(http.Request request) {
    if (authType == 'basic' && username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      request.headers['Authorization'] = 'Basic $credentials';
    } else if (authType == 'bearer' && authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    } else if (authType == 'api_key' && authToken != null) {
      final headerName = action.properties['api_key_header'] ?? 'X-API-Key';
      request.headers[headerName] = authToken!;
    }
  }

  /// Calculate checksum using the specified algorithm.
  String _calculateChecksum(List<int> bytes, String algorithm) {
    switch (algorithm.toLowerCase()) {
      case 'md5':
        return md5.convert(bytes).toString();
      case 'sha1':
        return sha1.convert(bytes).toString();
      case 'sha256':
      default:
        return sha256.convert(bytes).toString();
    }
  }
}
