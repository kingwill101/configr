import 'dart:convert';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/extensions/map.dart';
import 'package:configr/src/extensions/string.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:path/path.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file/file.dart';

class FileBackupModule extends ResourceModule {
  // State getters
  bool get hadToCreateDstDir => state['hadToCreateDstDir'] as bool? ?? false;

  bool get destinationFileExisted =>
      state['destinationFileExisted'] as bool? ?? false;

  String? get backupPath => state['backupPath'] as String?;

  bool get isDirectory => state['isDirectory'] as bool? ?? false;

  // Enhanced backup features
  bool get incremental => state['incremental'] as bool? ?? false;
  bool get compression => state['compression'] as bool? ?? false;
  bool get encryption => state['encryption'] as bool? ?? false;
  String get compressionFormat => state['compressionFormat'] as String? ?? 'zip';
  String? get encryptionKey => state['encryptionKey'] as String?;
  String? get encryptionAlgorithm => state['encryptionAlgorithm'] as String? ?? 'aes-256-gcm';
  String? get manifestPath => state['manifestPath'] as String?;
  Map<String, String> get fileHashes => Map<String, String>.from(state['fileHashes'] as Map? ?? {});

  FileBackupModule(super.file, super.action, {super.fileSystem, super.eventBus});

  @override
  Future<void> execute() async {
    final props = action.properties.requires(['backup_path']);
    final String destination = (props['backup_path'] as String);
    
    // Initialize enhanced backup features
    _initializeBackupFeatures();
    
    emitEvent(StartedEvent(
        moduleId: action.id,
        message: 'Starting backup of $source to $destination'));
    updateState({'backupPath': destination});

    final destinationDir = dirname(destination);
    final existCheck =
        await FileUtils.pathExists(source, fileSystem: fileSystem);

    if (!existCheck.exists) {
      throw SourceNotFoundException(source);
    }

    updateState({'isDirectory': existCheck.isDir});

    if (!await FileUtils.directoryExists(destinationDir,
        fileSystem: fileSystem)) {
      logger.info('Creating directory $destinationDir');
      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Creating directory $destinationDir'));
      try {
        await FileUtils.createDirectory(destinationDir, fileSystem: fileSystem);
        updateState({'hadToCreateDstDir': true});
      } catch (e) {
        emitEvent(FailedEvent(
            moduleId: action.id,
            message: 'Failed to create directory $destinationDir'));
        throw ActionFailedException(
            'Failed to create directory $destinationDir', moduleId: action.id);
      }
    }

    final destExists =
        await FileUtils.fileExists(destination, fileSystem: fileSystem);
    updateState({'destinationFileExisted': destExists});

    try {
      if (incremental && destExists) {
        await _performIncrementalBackup(destination);
      } else {
        await _performFullBackup(destination);
      }
      
      updateState({'backupCompleted': true});
      emitEvent(CompletedEvent(
          moduleId: action.id, message: 'Backup completed successfully'));
    } catch (e, stackTrace) {
      updateState(
          {'error': e.toString(), 'stackTrace': stackTrace.toString()});
      emitEvent(FailedEvent(
          moduleId: action.id, message: 'Backup failed: ${e.toString()}'));
      throw ActionFailedException(
          'Failed to backup file $source', moduleId: action.id, cause: e, stackTrace: stackTrace);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(
        moduleId: action.id, message: 'Starting rollback of backup'));
    
    if (!destinationFileExisted) {
      // Delete main backup
      if (isDirectory) {
        if (await FileUtils.directoryExists(backupPath!,
            fileSystem: fileSystem)) {
          logger.info('Deleting directory backup $backupPath');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Deleting directory backup $backupPath'));
          await FileUtils.deleteDirectory(backupPath!,
              recursive: true, fileSystem: fileSystem);
        }
      } else {
        if (await FileUtils.fileExists(backupPath!, fileSystem: fileSystem)) {
          logger.info('Deleting file backup $backupPath');
          emitEvent(StatusUpdateEvent(
              moduleId: action.id,
              level: StatusEvent.info,
              message: 'Deleting file backup $backupPath'));
          await FileUtils.deleteFile(backupPath!, fileSystem: fileSystem);
        }
      }

      // Delete incremental backups
      final incrementalPath = state['incrementalBackupPath'] as String?;
      if (incrementalPath != null && await FileUtils.fileExists(incrementalPath, fileSystem: fileSystem)) {
        logger.info('Deleting incremental backup $incrementalPath');
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Deleting incremental backup $incrementalPath'));
        await FileUtils.deleteFile(incrementalPath, fileSystem: fileSystem);
      }

      // Delete manifest
      final manifestPath = state['manifestPath'] as String?;
      if (manifestPath != null && await FileUtils.fileExists(manifestPath, fileSystem: fileSystem)) {
        logger.info('Deleting manifest $manifestPath');
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Deleting manifest $manifestPath'));
        await FileUtils.deleteFile(manifestPath, fileSystem: fileSystem);
      }
    }

    if (hadToCreateDstDir) {
      final destinationDir = dirname(backupPath!);
      if (await FileUtils.directoryExists(destinationDir,
          fileSystem: fileSystem)) {
        try {
          final dirContents =
              await fileSystem!.directory(destinationDir).list().toList();
          if (dirContents.isEmpty) {
            logger.info('Removing created empty directory $destinationDir');
            emitEvent(StatusUpdateEvent(
                moduleId: action.id,
                level: StatusEvent.info,
                message: 'Removing created empty directory $destinationDir'));
            await FileUtils.deleteDirectory(destinationDir,
                fileSystem: fileSystem);
          }
        } catch (e) {
          emitEvent(FailedEvent(
              moduleId: action.id,
              message: 'Failed to check/remove directory $destinationDir'));

          throw ActionFailedException(
              'Failed to check/remove directory $destinationDir', moduleId: action.id, cause: e);
        }
      }
    }

    emitEvent(CompletedEvent(
        moduleId: action.id, message: 'Rollback completed successfully'));
    updateState({'rollbackCompleted': true});
    await saveState();
  }

  void _initializeBackupFeatures() {
    updateState({
      'incremental': action.properties.containsKey('incremental') &&
          action.properties['incremental'] == 'true',
      'compression': action.properties.containsKey('compression') &&
          action.properties['compression'] == 'true',
      'encryption': action.properties.containsKey('encryption') &&
          action.properties['encryption'] == 'true',
      'compressionFormat': (action.properties.containsKey('compression_format')
          ? action.properties['compression_format'] as String
          : 'zip').unquote().unescape(),
      'encryptionKey': action.properties.containsKey('encryption_key')
          ? (action.properties['encryption_key'] as String).unquote().unescape()
          : null,
      'encryptionAlgorithm': (action.properties.containsKey('encryption_algorithm')
          ? action.properties['encryption_algorithm'] as String
          : 'aes-256-gcm').unquote().unescape(),
    });
  }

  Future<void> _performFullBackup(String destination) async {
    bool recursive = action.properties.containsKey('recursive') &&
        action.properties['recursive'] == 'true';

    emitEvent(StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Creating full backup...'));

    if (compression || encryption) {
      await _createCompressedBackup(destination, recursive);
    } else {
      if (isDirectory) {
        logger.info('Backing up dir $source -> $destination');
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Backing up directory $source -> $destination'));
        await FileUtils.copyDir(source, destination,
            recursive: recursive, fileSystem: fileSystem);
      } else {
        logger.info('Backing up file $source -> $destination');
        emitEvent(StatusUpdateEvent(
            moduleId: action.id,
            level: StatusEvent.info,
            message: 'Backing up file $source -> $destination'));
        await FileUtils.copyFile(source, destination, fileSystem: fileSystem);
      }
    }

    // Create manifest for incremental backups
    if (incremental) {
      await _createManifest(destination);
    }
  }

  Future<void> _performIncrementalBackup(String destination) async {
    emitEvent(StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Performing incremental backup...'));

    // Load existing manifest
    final manifest = await _loadManifest(destination);
    final currentHashes = await _calculateFileHashes();
    
    // Find changed files
    final changedFiles = <String>[];
    for (final entry in currentHashes.entries) {
      if (manifest[entry.key] != entry.value) {
        changedFiles.add(entry.key);
      }
    }

    if (changedFiles.isEmpty) {
      emitEvent(StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'No changes detected, skipping backup'));
      return;
    }

    emitEvent(StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Found ${changedFiles.length} changed files'));

    // Create incremental backup with only changed files
    await _createIncrementalBackup(destination, changedFiles);
    
    // Update manifest
    await _updateManifest(destination, currentHashes);
  }

  Future<void> _createCompressedBackup(String destination, bool recursive) async {
    emitEvent(StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Creating compressed backup...'));

    final archive = Archive();
    
    if (isDirectory) {
      await _addDirectoryToArchive(source, archive, recursive: recursive);
    } else {
      final fileContent = await FileUtils.readFile(source, fileSystem: fileSystem);
      final fileName = basename(source);
      archive.addFile(ArchiveFile(fileName, fileContent.length, fileContent.codeUnits));
    }

    List<int> compressedData;
    if (compressionFormat == "zip") {
      compressedData = ZipEncoder().encode(archive);
    } else if (compressionFormat == 'tar.gz') {
      final tarData = TarEncoder().encode(archive);
      compressedData = GZipEncoder().encode(tarData);
    } else {
      throw Exception('Unsupported compression format: $compressionFormat');
    }

    // Apply encryption if enabled
    if (encryption) {
      compressedData = await _encryptData(compressedData);
    }

    // Write to destination
    await FileUtils.writeFile(
        recursive: true,
        destination,
        String.fromCharCodes(compressedData),
        fileSystem: fileSystem);
  }

  Future<void> _createIncrementalBackup(String destination, List<String> changedFiles) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final incrementalPath = '${destination}.inc.$timestamp';
    
    if (compression || encryption) {
      final archive = Archive();
      for (final filePath in changedFiles) {
        final fullPath = isDirectory ? join(source, filePath) : source;
        if (await FileUtils.fileExists(fullPath, fileSystem: fileSystem)) {
          final fileContent = await FileUtils.readFile(fullPath, fileSystem: fileSystem);
          archive.addFile(ArchiveFile(filePath, fileContent.length, fileContent.codeUnits));
        }
      }

      List<int> compressedData;
      if (compressionFormat == "zip") {
        compressedData = ZipEncoder().encode(archive);
      } else if (compressionFormat == 'tar.gz') {
        final tarData = TarEncoder().encode(archive);
        compressedData = GZipEncoder().encode(tarData);
      } else {
        throw Exception('Unsupported compression format: $compressionFormat');
      }

      if (encryption) {
        compressedData = await _encryptData(compressedData);
      }

      await FileUtils.writeFile(
          recursive: true,
          incrementalPath,
          String.fromCharCodes(compressedData),
          fileSystem: fileSystem);
    } else {
      // Simple incremental backup without compression
      for (final filePath in changedFiles) {
        final sourcePath = isDirectory ? join(source, filePath) : source;
        final destPath = isDirectory ? join(incrementalPath, filePath) : incrementalPath;
        
        if (await FileUtils.fileExists(sourcePath, fileSystem: fileSystem)) {
          await FileUtils.createDirectory(dirname(destPath), fileSystem: fileSystem);
          await FileUtils.copyFile(sourcePath, destPath, fileSystem: fileSystem);
        }
      }
    }

    updateState({'incrementalBackupPath': incrementalPath});
  }

  Future<void> _addDirectoryToArchive(String dirPath, Archive archive, {bool recursive = false}) async {
    final dir = fileSystem!.directory(dirPath);
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File) {
        final relativePath = fileSystem!.path.relative(entity.path, from: dirPath);
        final fileContent = entity.readAsBytesSync();
        archive.addFile(ArchiveFile(relativePath, fileContent.length, fileContent));
      }
    }
  }

  Future<List<int>> _encryptData(List<int> data) async {
    if (encryptionKey == null) {
      throw Exception('Encryption key is required when encryption is enabled');
    }

    // Simple XOR encryption for demonstration (in production, use proper encryption)
    final key = utf8.encode(encryptionKey!);
    final encrypted = <int>[];
    
    for (int i = 0; i < data.length; i++) {
      encrypted.add(data[i] ^ key[i % key.length]);
    }
    
    return encrypted;
  }

  Future<Map<String, String>> _calculateFileHashes() async {
    final hashes = <String, String>{};
    
    if (isDirectory) {
      final dir = fileSystem!.directory(source);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = fileSystem!.path.relative(entity.path, from: source);
          final content = await entity.readAsBytes();
          final hash = sha256.convert(content).toString();
          hashes[relativePath] = hash;
        }
      }
    } else {
      final content = await FileUtils.readFile(source, fileSystem: fileSystem);
      final hash = sha256.convert(content.codeUnits).toString();
      hashes[basename(source)] = hash;
    }
    
    return hashes;
  }

  Future<void> _createManifest(String destination) async {
    final manifestPath = '$destination.manifest';
    final hashes = await _calculateFileHashes();
    
    final manifest = {
      'timestamp': DateTime.now().toIso8601String(),
      'source': basename(source),
      'files': hashes,
    };
    
    await FileUtils.writeFile(
        recursive: true,
        manifestPath,
        jsonEncode(manifest),
        fileSystem: fileSystem);
    
    updateState({'manifestPath': manifestPath, 'fileHashes': hashes});
  }

  Future<Map<String, String>> _loadManifest(String destination) async {
    final manifestPath = '$destination.manifest';
    
    if (!await FileUtils.fileExists(manifestPath, fileSystem: fileSystem)) {
      return {};
    }
    
    final content = await FileUtils.readFile(manifestPath, fileSystem: fileSystem);
    final manifest = jsonDecode(content) as Map<String, dynamic>;
    
    return Map<String, String>.from(manifest['files'] as Map? ?? {});
  }

  Future<void> _updateManifest(String destination, Map<String, String> hashes) async {
    final manifestPath = '$destination.manifest';
    
    final manifest = {
      'timestamp': DateTime.now().toIso8601String(),
      'source': basename(source),
      'files': hashes,
    };
    
    await FileUtils.writeFile(
        recursive: true,
        manifestPath,
        jsonEncode(manifest),
        fileSystem: fileSystem);
    
    updateState({'fileHashes': hashes});
  }
}
