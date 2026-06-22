import 'dart:io';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/extensions/string.dart';
import 'package:configr/src/modules/resource/resource_module.dart';
import 'package:configr/src/utils/file_utils.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:archive/archive.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

class FileCompressModule extends ResourceModule {
  // State getters
  bool get destinationFileExisted => state['destinationFileExisted'] as bool? ?? false;
  String get format => state['format'] as String? ?? 'zip';
  bool get recursive => state['recursive'] as bool? ?? false;
  int get compressionLevel => state['compressionLevel'] as int? ?? 6;
  List<String> get includePatterns => state['includePatterns'] as List<String>? ?? [];
  List<String> get excludePatterns => state['excludePatterns'] as List<String>? ?? [];
  bool get preserveStructure => state['preserveStructure'] as bool? ?? true;

  FileCompressModule(super.file, super.action,
      {super.allowedActions = const ['compress'], super.fileSystem, super.eventBus});

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting compression of $source'));
    
    // Initialize state with enhanced properties
    final format = (action.properties.containsKey("format") 
        ? action.properties['format'] as String 
        : 'zip').unquote().unescape();
    
    final compressionLevel = action.properties.containsKey('compressionLevel')
        ? int.tryParse(action.properties['compressionLevel'].toString()) ?? 6
        : 6;
    
    final includePatterns = action.properties.containsKey('include')
        ? (action.properties['include'] as String).split(',').map((s) => s.trim()).toList()
        : <String>[];
        
    final excludePatterns = action.properties.containsKey('exclude')
        ? (action.properties['exclude'] as String).split(',').map((s) => s.trim()).toList()
        : <String>[];
    
    updateState({
      'format': format,
      'recursive': action.properties.containsKey('recursive') &&
          action.properties['recursive'] == 'true',
      'compressionLevel': compressionLevel.clamp(1, 9),
      'includePatterns': includePatterns,
      'excludePatterns': excludePatterns,
      'preserveStructure': action.properties.containsKey('preserveStructure') 
          ? action.properties['preserveStructure'] == 'true'
          : true,
    });
    
    // Validate format
    if (!_isSupportedFormat(format)) {
      throw ActionFailedException(
        'Unsupported compression format: $format. Supported formats: zip, tar, tar.gz, tgz, gz, tar.bz2, tbz2, tar.xz, txz, xz, tar.z, tz, z',
        moduleId: action.id,
      );
    }

    final pathExists = await FileUtils.pathExists(source, fileSystem: fileSystem ?? fs);
    if (!pathExists.exists) {
      throw SourceNotFoundException(source);
    }

    await executeModules();
    if (isRollingBack) {
      return;
    }

    final fileExists = await FileUtils.fileExists(destination, fileSystem: fileSystem);
    updateState({'destinationFileExisted': fileExists});

    logger.info('Compressing $source to $destination with format $format, level $compressionLevel');
    try {
      emitEvent(StatusUpdateEvent(moduleId: action.id, level: StatusEvent.info, message: 'Compressing files...'));
      
      List<int> compressedData;
      if (pathExists.isDir) {
        compressedData = await _compressDirectory(source);
      } else {
        compressedData = await _compressFile(source);
      }

      if (await FileUtils.fileExists(destination, fileSystem: fileSystem)) {
        logger.info('Deleting existing compressed file $destination');
        await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      }

      // Create parent directories if needed
      final destDir = path.dirname(destination);
      if (!await FileUtils.directoryExists(destDir, fileSystem: fileSystem)) {
        await FileUtils.createDirectory(destDir, fileSystem: fileSystem);
      }
      
      // Write compressed data as bytes
      await (fileSystem ?? fs).file(destination).writeAsBytes(compressedData);
      logger.info('Compressed file $destination');

      updateState({'compressionCompleted': true});
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Compression completed successfully'));
    } catch (e, s) {
      updateState({'error': e.toString(), 'stackTrace': s.toString()});
      emitEvent(FailedEvent(moduleId: action.id, message: 'Compression failed: ${e.toString()}'));
      throw ActionFailedException('Failed to compress file $destination', moduleId: action.id, cause: e, stackTrace: s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  /// Compresses a directory with selective filtering and multiple format support
  Future<List<int>> _compressDirectory(String dirPath) async {
    final archive = Archive();
    await _addDirectoryToArchive(dirPath, archive);
    return _encodeArchive(archive);
  }

  /// Compresses a single file
  Future<List<int>> _compressFile(String filePath) async {
    if (!_shouldIncludeFile(filePath)) {
      throw ActionFailedException('File $filePath is excluded by patterns', moduleId: action.id);
    }
    
    final fileContent = await FileUtils.readFile(filePath, fileSystem: fileSystem);
    final archive = Archive();
    final fileName = path.basename(filePath);
    
    // Create ArchiveFile with compression level support
    final archiveFile = ArchiveFile(fileName, fileContent.length, fileContent.codeUnits);
    
    // Set compression level if not default (6)
    if (compressionLevel != 6) {
      archiveFile.compressionLevel = compressionLevel;
    }
    
    archive.addFile(archiveFile);
    
    return _encodeArchive(archive);
  }

  /// Encodes archive based on format with compression level support
  List<int> _encodeArchive(Archive archive) {
    switch (format.toLowerCase()) {
      case 'zip':
        return ZipEncoder().encode(archive);
      case 'tar':
        return TarEncoder().encode(archive);
      case 'tar.gz':
      case 'tgz':
        final tarData = TarEncoder().encode(archive);
        return GZipEncoder().encode(tarData);
      case 'gz':
        // For single files, create a gzip
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return GZipEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException('GZ format only supports single files', moduleId: action.id);
      case 'tar.bz2':
      case 'tbz2':
        final tarData = TarEncoder().encode(archive);
        return BZip2Encoder().encode(tarData);
      case 'tar.xz':
      case 'txz':
        final tarData = TarEncoder().encode(archive);
        return XZEncoder().encode(tarData);
      case 'xz':
        // For single files, create an xz
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return XZEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException('XZ format only supports single files', moduleId: action.id);
      case 'tar.z':
      case 'tz':
        final tarData = TarEncoder().encode(archive);
        return ZLibEncoder().encode(tarData);
      case 'z':
        // For single files, create a zlib
        if (archive.files.length == 1) {
          final file = archive.files.first;
          return ZLibEncoder().encode(file.content as List<int>);
        }
        throw ActionFailedException('Z format only supports single files', moduleId: action.id);
      default:
        throw ActionFailedException('Unsupported format: $format', moduleId: action.id);
    }
  }

  /// Adds directory contents to archive with selective filtering
  Future<void> _addDirectoryToArchive(String dirPath, Archive archive) async {
    final dir = fileSystem!.directory(dirPath);
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File && _shouldIncludeFile(entity.path)) {
        final relativePath = _getRelativePath(entity.path, dirPath);
        final fileContent = await FileUtils.readFile(entity.path, fileSystem: fileSystem);
        
        // Create ArchiveFile with compression level support
        final archiveFile = ArchiveFile(relativePath, fileContent.length, fileContent.codeUnits);
        
        // Set compression level if not default (6)
        if (compressionLevel != 6) {
          archiveFile.compressionLevel = compressionLevel;
        }
        
        archive.addFile(archiveFile);
        
        // Emit progress event
        emitEvent(StatusUpdateEvent(
          moduleId: action.id, 
          level: StatusEvent.info, 
          message: 'Added: $relativePath'
        ));
      }
    }
  }

  /// Determines if a file should be included based on include/exclude patterns
  bool _shouldIncludeFile(String filePath) {
    // If no patterns specified, include all files
    if (includePatterns.isEmpty && excludePatterns.isEmpty) {
      return true;
    }

    // Check exclude patterns first
    for (final pattern in excludePatterns) {
      if (_matchesPattern(filePath, pattern)) {
        return false;
      }
    }

    // If include patterns are specified, file must match at least one
    if (includePatterns.isNotEmpty) {
      for (final pattern in includePatterns) {
        if (_matchesPattern(filePath, pattern)) {
          return true;
        }
      }
      return false; // No include pattern matched
    }

    return true; // No exclude patterns matched and no include patterns specified
  }

  /// Checks if a file path matches a glob pattern
  bool _matchesPattern(String filePath, String pattern) {
    try {
      final glob = Glob(pattern);
      return glob.matches(filePath);
    } catch (e) {
      // Fallback to simple string matching if glob fails
      return filePath.contains(pattern);
    }
  }

  /// Gets relative path for archive entry
  String _getRelativePath(String filePath, String basePath) {
    if (preserveStructure) {
      return path.relative(filePath, from: basePath);
    } else {
      return path.basename(filePath);
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

  @override
  Future<void> rollback() async {
    if (!destinationFileExisted) {
      logger.info('Deleting compressed file $destination');
      await FileUtils.deleteFile(destination, fileSystem: fileSystem);
      updateState({'rollbackCompleted': true});
    }

    for (var module in childModules) {
      await module.rollback();
    }
    
    await saveState();
  }
}