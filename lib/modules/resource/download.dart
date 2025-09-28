import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

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

  FileDownloadModule(super.file, super.action,
      {super.allowedActions = const ['download'], super.fileSystem}) {
    updateState({
      'destinationFileExisted': false,
      'originalContent': null,
      'sourceUrl': '',
      'overwrite': false,
      'receivedBytes': 0,
      'totalBytes': -1
    });
  }

  Future<String> _downloadWithProgress(
      String url, String destinationPath) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        emitEvent(FailedEvent(
            message: 'Failed to download file: ${response.statusCode}',
            moduleId: action.id));
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      updateState(
          {'totalBytes': response.contentLength ?? -1, 'receivedBytes': 0});

      await Future.delayed(Duration(milliseconds: 100), () {});

      emitEvent(StartedEvent(
          message: 'Starting download from $url', moduleId: action.id));

      final file = fileSystem!.file(destinationPath);
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          updateState({'receivedBytes': receivedBytes + chunk.length});

          emitEvent(DownloadProgressEvent(
              current: receivedBytes,
              total: totalBytes,
              message: 'Downloading...',
              moduleId: action.id));
        }
      } finally {
        await sink.close();
      }

      final hash = sha256.convert(await file.readAsBytes()).toString();
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

    updateState({
      'sourceUrl': sourceUrlValue,
      'overwrite': action.properties.containsKey('overwrite') &&
          action.properties['overwrite'] == true
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
      final checksum = await _downloadWithProgress(sourceUrl, destinationPath);

      if (action.properties['checksum'] != null) {
        updateState({'expectedChecksum': action.properties['checksum']});

        if (checksum != expectedChecksum) {
          await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
          emitEvent(FailedEvent(
              message:
                  'Checksum validation failed: Expected $expectedChecksum, got $checksum',
              moduleId: action.id));
          throw ChecksumValidationException(
              destinationPath, expectedChecksum!, checksum);
        }

        emitEvent(StatusUpdateEvent(
            level: StatusEvent.info,
            message: 'Checksum verification passed',
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
            message: 'Deleting downloaded file $destination',
            moduleId: action.id));
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }
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
}
