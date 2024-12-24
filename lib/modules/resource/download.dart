import 'package:crypto/crypto.dart';
import 'package:configr/exceptions.dart';
// ignore: unnecessary_import
import 'package:configr/exceptions.dart'
    show DestinationExistsException, ChecksumValidationException;
import 'package:configr/extensions/string.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/file_utils.dart';
import 'package:configr/utils/logging.dart';
import 'package:http/http.dart' as http;

class FileDownloadModule extends ResourceModule {
  bool destinationFileExisted = false;
  String? originalContent;

  FileDownloadModule(super.file, super.action,
      {super.allowedActions = const ['download'], super.fileSystem});

  @override
  Future<void> call() async {
    final sourceUrl = source.unquote();
    final destinationPath = file.destination.clean();

    bool overwrite = action.properties.containsKey('overwrite') &&
        action.properties['overwrite'] == 'true';

    await executeModules();
    if (isRollingBack) {
      return;
    }

    destinationFileExisted =
        await FileUtils.fileExists(destinationPath, fileSystem: fileSystem);

    if (destinationFileExisted && !overwrite) {
      throw DestinationExistsException(destinationPath);
    }

    if (destinationFileExisted) {
      originalContent =
          await FileUtils.readFile(destinationPath, fileSystem: fileSystem);
    }

    logger.info('Downloading file from $sourceUrl to $destinationPath');
    try {
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode == 200) {
        await FileUtils.writeFile(destinationPath, response.body,
            fileSystem: fileSystem);

        // Always calculate checksum
        final actualChecksum = sha256.convert(response.bodyBytes).toString();
        action.sha256 = actualChecksum;

        // Verify checksum if provided
        final expectedChecksum = action.properties['checksum'];
        if (expectedChecksum != null) {
          if (actualChecksum != expectedChecksum) {
            await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
            throw ChecksumValidationException(
                destinationPath, expectedChecksum, actualChecksum);
          }
          logger.info('Checksum verification passed for $destinationPath');
        } else {
          logger.info('File downloaded successfully. SHA-256: $actualChecksum');
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      throw ActionFailedException('Error downloading file: $e');
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
  }

  @override
  Future<void> rollback() async {
    final destinationPath = file.destination.clean();

    if (destinationFileExisted) {
      if (originalContent != null) {
        logger.info('Restoring original content to $destinationPath');
        await FileUtils.writeFile(destinationPath, originalContent!,
            fileSystem: fileSystem);
      } else {
        logger.info('Deleting downloaded file $destinationPath');
        await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
      }
    } else {
      logger.info('Deleting downloaded file $destinationPath');
      await FileUtils.deleteFile(destinationPath, fileSystem: fileSystem);
    }

    for (var module in childModules) {
      await module.rollback();
    }
  }
}
