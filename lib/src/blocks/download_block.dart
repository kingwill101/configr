import 'dart:convert';
import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:crypto/crypto.dart' show sha256, md5, sha1;
import 'package:http/http.dart' as http;
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `download` config action.
///
/// Downloads a file from a URL with resume capability, authentication,
/// checksum verification, and rollback.
///
/// ```i3
/// download {
///   source = "https://example.com/file.zip"
///   destination = "/tmp/file.zip"
///   checksum = "abc123..."
///   checksum_algorithm = "sha256"     # sha256 | md5 | sha1
///   overwrite = true
///   resume = true
///   auth_type = "bearer"
///   auth_token = "token123"
/// }
/// ```
class DownloadBlock extends ActionBlock {
  @override
  String get blockType => 'download';

  // ---------------------------------------------------------------------------
  // Download-specific properties
  // ---------------------------------------------------------------------------

  String? checksum;
  String? expectedChecksum;
  String checksumAlgorithm = 'sha256';
  bool overwrite = false;
  bool resumeEnabled = false;
  String? authType;
  String? authToken;
  String? username;
  String? password;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool destinationFileExisted = false;
  String? originalContent;
  String? actualChecksum;
  int receivedBytes = 0;
  int totalBytes = -1;
  bool isResumed = false;
  int resumePosition = 0;
  int downloadSpeed = 0;
  int downloadDurationMs = 0;

  DownloadBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    'checksum': ?checksum,
    if (checksumAlgorithm != 'sha256') 'checksum_algorithm': checksumAlgorithm,
    'auth_type': ?authType,
    'auth_token': ?authToken,
    'username': ?username,
    'password': ?password,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (overwrite) 'overwrite': overwrite,
    if (resumeEnabled) 'resume': resumeEnabled,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    checksum = context.getVariable('checksum') as String?;
    checksumAlgorithm =
        (context.getVariable('checksum_algorithm') as String?) ?? 'sha256';

    overwrite = switch (context.getVariable('overwrite')) {
      true || 'true' => true,
      _ => false,
    };

    resumeEnabled = switch (context.getVariable('resume')) {
      true || 'true' => true,
      _ => false,
    };

    authType = context.getVariable('auth_type') as String?;
    authToken = context.getVariable('auth_token') as String?;
    username = context.getVariable('username') as String?;
    password = context.getVariable('password') as String?;
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  String dryRunSummary() {
    if (source.isNotEmpty && destination.isNotEmpty) {
      return '$blockType: $source → $destination';
    }
    return super.dryRunSummary();
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Downloading from $source'));

    // Check destination
    final exists = await fileService.fileExists(destination);
    destinationFileExisted = exists;

    if (exists && !overwrite) {
      throw DestinationExistsException(destination);
    }

    if (exists) {
      final content = await fileService.readFile(destination);
      originalContent = content;
      await fileService.deleteFile(destination);
    }

    // Execute child blocks
    for (final child in children) {
      await child.execute();
    }

    try {
      final startTime = DateTime.now();
      final checksum = await _downloadWithProgress(source, destination);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      downloadDurationMs = duration.inMilliseconds;
      downloadSpeed = duration.inMilliseconds > 0
          ? (receivedBytes * 1000 / duration.inMilliseconds).round()
          : 0;

      // Verify checksum if expected
      if (expectedChecksum != null && checksum != expectedChecksum) {
        await fileService.deleteFile(destination);
        throw ActionFailedException(
          'Checksum validation failed: expected $expectedChecksum, got $checksum',
          moduleId: id,
        );
      }

      if (expectedChecksum != null) {
        emitEvent(
          StatusUpdateEvent(
            moduleId: id,
            level: StatusEvent.info,
            message: 'Checksum verification passed ($checksumAlgorithm)',
          ),
        );
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Download completed in ${duration.inMilliseconds}ms',
        ),
      );
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Download failed: $e'));
      throw ActionFailedException(
        'Failed to download from $source',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Rolling back download'));

    try {
      if (destinationFileExisted && originalContent != null) {
        await fileService.writeFile(destination, originalContent!);
      } else {
        if (await fileService.fileExists(destination)) {
          await fileService.deleteFile(destination);
        }
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Download rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Download rollback failed: $e'),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<String> _downloadWithProgress(
    String url,
    String destinationPath,
  ) async {
    final client = http.Client();
    final fSys = fileSystem;
    try {
      final request = http.Request('GET', Uri.parse(url));
      _addAuthenticationHeaders(request);

      // Handle resume
      if (resumeEnabled) {
        final destFile = fSys.file(destinationPath);
        if (await destFile.exists()) {
          resumePosition = await destFile.length();
          request.headers['Range'] = 'bytes=$resumePosition-';
          isResumed = true;
        }
      }

      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw ActionFailedException(
          'Failed to download: HTTP ${response.statusCode}',
          moduleId: id,
        );
      }

      totalBytes = response.contentLength ?? -1;
      receivedBytes = 0;

      final destFile = fSys.file(destinationPath);
      final sink = destFile.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          emitEvent(
            DownloadProgressEvent(
              current: receivedBytes,
              total: totalBytes,
              message: isResumed ? 'Resuming download...' : 'Downloading...',
              moduleId: id,
            ),
          );
        }
      } finally {
        await sink.close();
      }

      final fileBytes = await destFile.readAsBytes();
      final hash = _calculateChecksum(fileBytes);
      actualChecksum = hash;

      return hash;
    } finally {
      client.close();
    }
  }

  void _addAuthenticationHeaders(http.Request request) {
    if (authType == 'basic' && username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      request.headers['Authorization'] = 'Basic $credentials';
    } else if (authType == 'bearer' && authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    } else if (authType == 'api_key' && authToken != null) {
      request.headers['X-API-Key'] = authToken!;
    }
  }

  String _calculateChecksum(List<int> bytes) {
    switch (checksumAlgorithm.toLowerCase()) {
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
