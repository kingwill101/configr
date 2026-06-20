import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/extensions/string.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:archive/archive.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

class FileDecompressModule extends ResourceModule {
  // State getters
  List<String> get createdFiles {
    // First check module state, then fall back to action state for rollback
    final moduleFiles = (state['createdFiles'] as List<dynamic>? ?? [])
        .cast<String>();
    if (moduleFiles.isNotEmpty) {
      return moduleFiles;
    }

    // For rollback, check action state
    final actionFiles = (action.state['createdFiles'] as List<dynamic>? ?? [])
        .cast<String>();
    return actionFiles;
  }

  String get format => state['format'] as String? ?? 'zip';
  bool get sourceExists => state['sourceExists'] as bool? ?? false;
  List<String> get includePatterns => state['includePatterns'] as List<String>? ?? [];
  List<String> get excludePatterns => state['excludePatterns'] as List<String>? ?? [];
  bool get preserveStructure => state['preserveStructure'] as bool? ?? true;
  int get totalFiles => state['totalFiles'] as int? ?? 0;
  int get extractedFiles => state['extractedFiles'] as int? ?? 0;

  FileDecompressModule(
    super.file,
    super.action, {
    super.allowedActions = const ['decompress'],
    super.fileSystem,
    super.eventBus,
  }) {
    updateState({
      'createdFiles': [], 
      'sourceExists': false, 
      'format': 'zip',
      'includePatterns': [],
      'excludePatterns': [],
      'preserveStructure': true,
      'totalFiles': 0,
      'extractedFiles': 0,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting decompression of $source',
      ),
    );

    // Initialize enhanced properties
    final format = (action.properties.containsKey("format")
            ? action.properties['format'] as String
            : 'zip')
        .unquote()
        .unescape();
    
    final includePatterns = action.properties.containsKey('include')
        ? (action.properties['include'] as String).split(',').map((s) => s.trim()).toList()
        : <String>[];
        
    final excludePatterns = action.properties.containsKey('exclude')
        ? (action.properties['exclude'] as String).split(',').map((s) => s.trim()).toList()
        : <String>[];

    updateState({
      'format': format,
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'preserveStructure': action.properties.containsKey('preserveStructure') 
          ? action.properties['preserveStructure'] == 'true'
          : true,
    });

    // Validate format
    if (!_isSupportedFormat(format)) {
      throw ActionFailedException(
        'Unsupported decompression format: $format. Supported formats: zip, tar, tar.gz, tgz, gz, tar.bz2, tbz2, tar.xz, txz, xz, tar.z, tz, z',
        moduleId: action.id,
      );
    }

    final exists = await FileUtils.fileExists(source, fileSystem: fileSystem);
    updateState({'sourceExists': exists});

    if (!exists) {
      logger.severe('Source archive $source does not exist');
      throw SourceNotFoundException(source);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    logger.info('Decompressing $source to $destination with format $format');
    try {
      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Reading archive...',
        ),
      );

      final data = await FileUtils.readBinaryFile(
        source,
        fileSystem: fileSystem,
      );

      final archive = _decodeArchive(data, format);
      
      // Count total files for progress tracking
      final totalFiles = archive.files.length;
      updateState({'totalFiles': totalFiles});

      emitEvent(
        StatusUpdateEvent(
          moduleId: action.id,
          level: StatusEvent.info,
          message: 'Found $totalFiles files in archive. Starting extraction...',
        ),
      );

      List<String> newFiles = [];
      int extractedCount = 0;

      for (final file in archive) {
        if (_shouldExtractFile(file.name)) {
          final filePath = _getExtractionPath(file.name);
          
          if (file.isFile) {
            logger.info('Extracting file: ${file.name}');
            await FileUtils.writeFile(
              recursive: true,
              filePath,
              String.fromCharCodes(file.content),
              fileSystem: fileSystem,
            );
            newFiles.add(filePath);
            extractedCount++;
          } else {
            // Create directory
            await FileUtils.createDirectory(filePath, fileSystem: fileSystem);
          }

          // Update progress
          updateState({'extractedFiles': extractedCount});
          
          // Emit progress event every 10 files or for the last file
          if (extractedCount % 10 == 0 || extractedCount == totalFiles) {
            emitEvent(
              StatusUpdateEvent(
                moduleId: action.id,
                level: StatusEvent.info,
                message: 'Extracted $extractedCount of $totalFiles files...',
              ),
            );
          }
        } else {
          logger.info('Skipping file (filtered): ${file.name}');
        }
      }

      updateState({
        'createdFiles': newFiles, 
        'decompressionCompleted': true,
        'extractedFiles': extractedCount,
      });

      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message: 'Decompression completed successfully. Extracted $extractedCount files.',
        ),
      );
    } catch (e, s) {
      updateState({'error': e.toString(), 'stackTrace': s.toString()});
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Decompression failed: ${e.toString()}',
        ),
      );
      throw ActionFailedException('Failed to decompress file $source', moduleId: action.id, cause: e, stackTrace: s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    try {
      // Instead of deleting individual files, remove the entire destination directory
      if (await FileUtils.directoryExists(
        destination,
        fileSystem: fileSystem,
      )) {
        logger.info(
          'Removing decompression directory $destination recursively',
        );
        await FileUtils.deleteDirectory(
          destination,
          fileSystem: fileSystem,
          recursive: true,
        );
      } else {
        logger.info(
          'Decompression directory $destination does not exist, skipping cleanup',
        );
      }
      updateState({'rollbackCompleted': true});
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString(),
      });
      rethrow;
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }

  /// Decodes archive based on format with support for multiple formats
  Archive _decodeArchive(List<int> data, String format) {
    switch (format.toLowerCase()) {
      case 'zip':
        return ZipDecoder().decodeBytes(data);
      case 'tar':
        return TarDecoder().decodeBytes(data);
      case 'tar.gz':
      case 'tgz':
        final gzipData = GZipDecoder().decodeBytes(data);
        return TarDecoder().decodeBytes(gzipData);
      case 'tar.bz2':
      case 'tbz2':
        final bzip2Data = BZip2Decoder().decodeBytes(data);
        return TarDecoder().decodeBytes(bzip2Data);
      case 'gz':
        // For single file gzip, create a simple archive
        final gzipData = GZipDecoder().decodeBytes(data);
        final archive = Archive();
        // For GZ format, we need to determine the original filename
        // Since GZ doesn't preserve filename in archive, we'll use the source filename
        // but remove the .gz extension and try to infer the original name
        String fileName;
        final sourceBaseName = path.basename(source);
        if (sourceBaseName.endsWith('.gz')) {
          fileName = sourceBaseName.substring(0, sourceBaseName.length - 3);
        } else {
          fileName = sourceBaseName;
        }
        archive.addFile(ArchiveFile(fileName, gzipData.length, gzipData));
        return archive;
      case 'tar.xz':
      case 'txz':
        final xzData = XZDecoder().decodeBytes(data);
        return TarDecoder().decodeBytes(xzData);
      case 'xz':
        // For single file xz, create a simple archive
        final xzData = XZDecoder().decodeBytes(data);
        final archive = Archive();
        String fileName;
        final sourceBaseName = path.basename(source);
        if (sourceBaseName.endsWith('.xz')) {
          fileName = sourceBaseName.substring(0, sourceBaseName.length - 3);
        } else {
          fileName = sourceBaseName;
        }
        archive.addFile(ArchiveFile(fileName, xzData.length, xzData));
        return archive;
      case 'tar.z':
      case 'tz':
        final zlibData = ZLibDecoder().decodeBytes(data);
        return TarDecoder().decodeBytes(zlibData);
      case 'z':
        // For single file zlib, create a simple archive
        final zlibData = ZLibDecoder().decodeBytes(data);
        final archive = Archive();
        String fileName;
        final sourceBaseName = path.basename(source);
        if (sourceBaseName.endsWith('.z')) {
          fileName = sourceBaseName.substring(0, sourceBaseName.length - 2);
        } else {
          fileName = sourceBaseName;
        }
        archive.addFile(ArchiveFile(fileName, zlibData.length, zlibData));
        return archive;
      default:
        throw ActionFailedException('Unsupported format: $format', moduleId: action.id);
    }
  }

  /// Determines if a file should be extracted based on include/exclude patterns
  bool _shouldExtractFile(String fileName) {
    // If no patterns specified, extract all files
    if (includePatterns.isEmpty && excludePatterns.isEmpty) {
      return true;
    }

    // Check exclude patterns first
    for (final pattern in excludePatterns) {
      if (_matchesPattern(fileName, pattern)) {
        return false;
      }
    }

    // If include patterns are specified, file must match at least one
    if (includePatterns.isNotEmpty) {
      for (final pattern in includePatterns) {
        if (_matchesPattern(fileName, pattern)) {
          return true;
        }
      }
      return false; // No include pattern matched
    }

    return true; // No exclude patterns matched and no include patterns specified
  }

  /// Checks if a file name matches a glob pattern
  bool _matchesPattern(String fileName, String pattern) {
    try {
      final glob = Glob(pattern);
      return glob.matches(fileName);
    } catch (e) {
      // Fallback to simple string matching if glob fails
      return fileName.contains(pattern);
    }
  }

  /// Gets the extraction path for a file based on preserveStructure setting
  String _getExtractionPath(String fileName) {
    if (preserveStructure) {
      return fileSystem!.path.join(destination, fileName);
    } else {
      // Extract only the filename, ignoring directory structure
      final baseName = path.basename(fileName);
      return fileSystem!.path.join(destination, baseName);
    }
  }

  /// Validates if the specified format is supported
  bool _isSupportedFormat(String format) {
    const supportedFormats = [
      'zip', 'tar', 'tar.gz', 'tgz', 'gz', 
      'tar.bz2', 'tbz2', 'tar.xz', 'txz', 'xz',
      'tar.z', 'tz', 'z'
    ];
    return supportedFormats.contains(format.toLowerCase());
  }
}