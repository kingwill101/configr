import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `backup` config action.
///
/// Creates backups of files/directories with support for full and incremental
/// backups, compression, and encryption.
///
/// ```i3
/// backup {
///   source = "/path/to/source"
///   destination = "/path/to/backup"
///   strategy = "full"                  # full | incremental
///   compression = true
///   compression_format = "zip"         # zip | tar.gz | tgz
///   encryption = false
///   encryption_algorithm = "aes256"
/// }
/// ```
class BackupBlock extends ActionBlock {
  @override
  String get blockType => 'backup';

  // ---------------------------------------------------------------------------
  // Backup-specific properties
  // ---------------------------------------------------------------------------

  String strategy = 'full';
  bool compression = false;
  String compressionFormat = 'zip';
  bool encryption = false;
  String encryptionAlgorithm = 'aes256';
  bool incremental = false;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool hadToCreateDstDir = false;
  bool destinationFileExisted = false;
  List<String> backedUpFiles = [];
  Map<String, String> fileHashes = {};
  String? manifestPath;
  String? backupPath;

  BackupBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (strategy != 'full') 'strategy': strategy,
    if (compressionFormat != 'zip') 'compression_format': compressionFormat,
    if (encryptionAlgorithm != 'aes256')
      'encryption_algorithm': encryptionAlgorithm,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (compression) 'compression': compression,
    if (encryption) 'encryption': encryption,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    strategy = context.getVariable('strategy') as String? ?? strategy;
    incremental = strategy == 'incremental';

    compression = switch (context.getVariable('compression')) {
      true || 'true' => true,
      _ => false,
    };

    compressionFormat =
        (context.getVariable('compression_format') as String?) ?? 'zip';

    encryption = switch (context.getVariable('encryption')) {
      true || 'true' => true,
      _ => false,
    };

    encryptionAlgorithm =
        (context.getVariable('encryption_algorithm') as String?) ?? 'aes256';
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting backup of $source → $destination',
      ),
    );

    // Check source exists
    final exists = await fileService.pathExists(source);
    if (!exists.exists) {
      throw SourceNotFoundException(source);
    }

    // Ensure destination directory exists
    final destDir = path.dirname(destination);
    if (!await fileService.directoryExists(destDir)) {
      await fileService.createDirectory(destDir);
      hadToCreateDstDir = true;
    }

    // Check if destination already exists
    final destExists = await fileService.fileExists(
      destination,
    );
    destinationFileExisted = destExists;

    // Execute child blocks
    for (final child in children) {
      await child.execute();
    }

    try {
      if (incremental) {
        await _performIncrementalBackup();
      } else {
        await _performFullBackup();
      }

      // Create manifest if compression is enabled
      if (compression) {
        await _createManifest();
      }

      emitEvent(CompletedEvent(moduleId: id, message: 'Backup completed'));
    } catch (e, _) {
      emitEvent(FailedEvent(moduleId: id, message: 'Backup failed: $e'));
      throw ActionFailedException(
        'Failed to backup $source → $destination',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: id, message: 'Rolling back backup'));

    try {
      if (!destinationFileExisted) {
        if (await fileService.fileExists(destination)) {
          await fileService.deleteFile(destination);
        }
      }

      if (manifestPath != null &&
          await fileService.fileExists(manifestPath!)) {
        await fileService.deleteFile(manifestPath!);
      }

      if (hadToCreateDstDir) {
        final destDir = path.dirname(destination);
        if (await fileService.directoryExists(destDir)) {
          final dir = fileSystem.directory(destDir);
          final contents = await dir.list().toList();
          if (contents.isEmpty) {
            await fileService.deleteDirectory(
              destDir,
              recursive: true,
            );
          }
        }
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(moduleId: id, message: 'Backup rollback completed'),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Backup rollback failed: $e'),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _performFullBackup() async {
    final isDir = await fileService.directoryExists(
      source,
    );

    if (compression) {
      await _createCompressedBackup(source, destination);
    } else if (isDir) {
      // Copy entire directory
      if (await fileService.directoryExists(
        destination,
      )) {
        await fileService.deleteDirectory(
          destination,
          recursive: true,
        );
      }
      // Copy directory contents manually using FileUtils
      final srcDir = fileSystem.directory(source);
      await for (final entity in srcDir.list(recursive: true)) {
        final relPath = path.relative(entity.path, from: source);
        final destPath = path.join(destination, relPath);
        final destParent = fileSystem.directory(path.dirname(destPath));
        if (!await destParent.exists()) {
          await destParent.create(recursive: true);
        }
        await fileService.copyFile(entity.path, destPath);
      }
    } else {
      // Copy single file
      await fileService.copyFile(source, destination);
    }
  }

  Future<void> _performIncrementalBackup() async {
    // Load previous manifest to compare hashes
    final previousManifest = await _loadManifest();
    final currentHashes = await _calculateFileHashes(source);

    final changedFiles = <String>[];
    for (final entry in currentHashes.entries) {
      if (previousManifest[entry.key] != entry.value) {
        changedFiles.add(entry.key);
      }
    }

    if (changedFiles.isEmpty) {
      logger.info('No changes detected, skipping incremental backup');
      return;
    }

    fileHashes = currentHashes;

    if (compression) {
      await _createIncrementalBackup(source, destination, changedFiles);
    } else {
      // Copy only changed files
      for (final relativePath in changedFiles) {
        final src = path.join(source, relativePath);
        final dst = path.join(destination, relativePath);
        final dstDir = path.dirname(dst);

        if (!await fileService.directoryExists(dstDir)) {
          await fileService.createDirectory(dstDir);
        }
        await fileService.copyFile(src, dst);
      }
    }

    await _updateManifest(currentHashes);
  }

  Future<void> _createCompressedBackup(
    String sourcePath,
    String destPath,
  ) async {
    final archive = Archive();

    final isDir = await fileService.directoryExists(
      sourcePath,
    );

    if (isDir) {
      await _addDirectoryToArchive(sourcePath, archive);
    } else {
      final content = await fileService.readFile(
        sourcePath,
      );
      archive.addFile(
        ArchiveFile(
          path.basename(sourcePath),
          content.length,
          content.codeUnits,
        ),
      );
    }

    List<int> encoded;
    switch (compressionFormat.toLowerCase()) {
      case 'zip':
        encoded = ZipEncoder().encode(archive);
        break;
      case 'tar.gz':
      case 'tgz':
        encoded = GZipEncoder().encode(TarEncoder().encode(archive));
        break;
      default:
        encoded = ZipEncoder().encode(archive);
    }

    // Optionally encrypt
    if (encryption) {
      encoded = _encryptData(encoded);
    }

    if (await fileService.fileExists(destPath)) {
      await fileService.deleteFile(destPath);
    }
    await fileSystem.file(destPath).writeAsBytes(encoded);
  }

  Future<void> _createIncrementalBackup(
    String sourcePath,
    String destPath,
    List<String> changedFiles,
  ) async {
    final archive = Archive();

    for (final relativePath in changedFiles) {
      final fullPath = path.join(sourcePath, relativePath);
      if (await fileService.fileExists(fullPath)) {
        final content = await fileService.readFile(
          fullPath,
        );
        archive.addFile(
          ArchiveFile(relativePath, content.length, content.codeUnits),
        );
      }
    }

    List<int> encoded;
    switch (compressionFormat.toLowerCase()) {
      case 'zip':
        encoded = ZipEncoder().encode(archive);
        break;
      case 'tar.gz':
      case 'tgz':
        encoded = GZipEncoder().encode(TarEncoder().encode(archive));
        break;
      default:
        encoded = ZipEncoder().encode(archive);
    }

    if (encryption) {
      encoded = _encryptData(encoded);
    }

    await fileSystem.file(destPath).writeAsBytes(encoded);
  }

  Future<void> _addDirectoryToArchive(String dirPath, Archive archive) async {
    final dir = fileSystem.directory(dirPath);
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: dirPath);
        final content = await fileService.readFile(
          entity.path,
        );
        archive.addFile(
          ArchiveFile(relativePath, content.length, content.codeUnits),
        );
      }
    }
  }

  List<int> _encryptData(List<int> data) {
    // Placeholder encryption — in a real implementation this would use
    // actual encryption. For now, we just XOR with a simple key.
    const key = 0xAB;
    return data.map((b) => b ^ key).toList();
  }

  Future<Map<String, String>> _calculateFileHashes(String sourcePath) async {
    final hashes = <String, String>{};
    final isDir = await fileService.directoryExists(
      sourcePath,
    );

    if (isDir) {
      final dir = fileSystem.directory(sourcePath);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: sourcePath);
          final content = await fileService.readFile(
            entity.path,
          );
          hashes[relativePath] = sha256
              .convert(utf8.encode(content))
              .toString();
        }
      }
    } else {
      final content = await fileService.readFile(
        sourcePath,
      );
      hashes[path.basename(sourcePath)] = sha256
          .convert(utf8.encode(content))
          .toString();
    }

    return hashes;
  }

  Future<void> _createManifest() async {
    manifestPath = '$destination.manifest.json';
    final manifest = {
      'source': source,
      'destination': destination,
      'strategy': strategy,
      'compression': compression,
      'compression_format': compressionFormat,
      'encryption': encryption,
      'timestamp': DateTime.now().toIso8601String(),
      'file_hashes': fileHashes,
    };

    await fileService.writeFile(
      manifestPath!,
      jsonEncode(manifest),
    );
  }

  Future<Map<String, String>> _loadManifest() async {
    final manifestFile = '$destination.manifest.json';
    if (await fileService.fileExists(manifestFile)) {
      try {
        final content = await fileService.readFile(
          manifestFile,
        );
        final data = jsonDecode(content) as Map<String, dynamic>;
        final hashes = data['file_hashes'];
        if (hashes is Map<String, dynamic>) {
          return hashes.map((k, v) => MapEntry(k, v.toString()));
        }
      } catch (e) {
        logger.warning('Failed to load manifest: $e');
      }
    }
    return {};
  }

  Future<void> _updateManifest(Map<String, String> hashes) async {
    fileHashes = hashes;
    await _createManifest();
  }
}
