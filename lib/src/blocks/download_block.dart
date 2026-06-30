import 'dart:convert';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/network_service.dart';
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
///   transfer_mode = "auto"            # auto | remote | controller
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
  DownloadTransferMode transferMode = DownloadTransferMode.auto;
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
  void resetState() {
    super.resetState();
    checksum = null;
    expectedChecksum = null;
    checksumAlgorithm = 'sha256';
    overwrite = false;
    resumeEnabled = false;
    transferMode = DownloadTransferMode.auto;
    authType = null;
    authToken = null;
    username = null;
    password = null;
    destinationFileExisted = false;
    originalContent = null;
    actualChecksum = null;
    receivedBytes = 0;
    totalBytes = -1;
    isResumed = false;
    resumePosition = 0;
    downloadSpeed = 0;
    downloadDurationMs = 0;
  }

  @override
  Map<String, String> get additionalProperties => {
    'checksum': ?checksum,
    if (checksumAlgorithm != 'sha256') 'checksum_algorithm': checksumAlgorithm,
    if (transferMode != DownloadTransferMode.auto)
      'transfer_mode': transferMode.name,
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
    expectedChecksum = checksum;
    checksumAlgorithm =
        (context.getVariable('checksum_algorithm') as String?) ?? 'sha256';
    transferMode = DownloadTransferMode.parse(
      (context.getVariable('transfer_mode') ??
              context.getVariable('download_mode') ??
              'auto')
          .toString(),
    );

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
      final result = await networkService.downloadToFile(
        url: source,
        destinationPath: destination,
        checksumAlgorithm: checksumAlgorithm,
        headers: _authenticationHeaders(),
        resume: resumeEnabled,
        transferMode: transferMode,
        onProgress: (current, total, message) {
          receivedBytes = current;
          totalBytes = total;
          emitEvent(
            DownloadProgressEvent(
              current: current,
              total: total,
              message: message,
              moduleId: id,
            ),
          );
        },
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      downloadDurationMs = duration.inMilliseconds;
      receivedBytes = result.receivedBytes;
      downloadSpeed = duration.inMilliseconds > 0
          ? (receivedBytes * 1000 / duration.inMilliseconds).round()
          : 0;
      actualChecksum = result.checksum;

      // Verify checksum if expected
      if (expectedChecksum != null && result.checksum != expectedChecksum) {
        await fileService.deleteFile(destination);
        throw ActionFailedException(
          'Checksum validation failed: expected $expectedChecksum, got ${result.checksum}',
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

  Map<String, String> _authenticationHeaders() {
    final headers = <String, String>{};
    if (authType == 'basic' && username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $credentials';
    } else if (authType == 'bearer' && authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    } else if (authType == 'api_key' && authToken != null) {
      headers['X-API-Key'] = authToken!;
    }
    return headers;
  }
}
