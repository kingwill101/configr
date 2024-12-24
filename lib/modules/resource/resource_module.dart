import 'package:configr/exceptions.dart';
import 'package:configr/extensions/string.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/backup.dart';
import 'package:configr/modules/resource/compress.dart';
import 'package:configr/modules/resource/copy.dart';
import 'package:configr/modules/resource/decompress.dart';
import 'package:configr/modules/resource/delete.dart';
import 'package:configr/modules/resource/download.dart';
import 'package:configr/modules/resource/execute.dart';
import 'package:configr/modules/resource/permissions.dart';
import 'package:configr/modules/resource/rename.dart';
import 'package:configr/modules/resource/symlink.dart';
import 'package:configr/modules/module.dart';
import 'package:configr/modules/resource/touch.dart';
import 'package:configr/modules/resource/validate.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:file/file.dart';
import 'package:liquify/liquify.dart' as liquify;
import 'package:path/path.dart';

abstract class ResourceModule extends Module {
  final ResourceModel file;
  final Action action;
  final FileSystem? fileSystem;
  final List<String> allowedActions;
  final PrivilegeEscalation? privilegeEscalation;
  Map<String, dynamic> vars = {};
  List<ResourceModule> childModules = [];
  bool isRollingBack = false;
  File? templateFile;

  ResourceModule(
    this.file,
    this.action, {
    this.allowedActions = const [],
    this.fileSystem,
    this.privilegeEscalation,
    Map<String, dynamic>? templateVars,
    String? fileTemplate,
  }) {
    loadTemplate();
    resolveModules();
  }

  bool get isDir => file.type == ResourceType.directory;
  String get source {
    //check if the source attribute is present before using the file.source property
    final path = (action.properties["source"] as String? ?? file.source)
        .clean()
        .normalizePath();

    if (path.startsWith("http")) {
      return file.source;
    }

    return templateFile != null
        ? templateFile!.path
        : join((fileSystem ?? fs).currentDirectory.path, path);
  }

  String get destination => join(
      (fileSystem ?? fs).currentDirectory.path,
      (action.properties["destination"] as String? ?? file.destination)
          .clean()
          .normalizePath());

  loadTemplate() {
    if (file.template != null && file.template!.template != null) {
      final templateContent =
          (fileSystem ?? fs).file(file.template!.template!.clean());

      if (!templateContent.existsSync()) {
        throw ActionFailedException(
            'Template file ${templateContent.path} does not exist');
      }

      final tContent = liquify.Template.parse(
              templateContent.readAsStringSync(),
              data: file.template!.vars ?? {})
          .render();
      var cacheDir = (fileSystem ?? fs).directory(appDirs.cache);

      if (!cacheDir.existsSync()) {
        try {
          cacheDir.createSync();
        } catch (e) {
          cacheDir = (fileSystem ?? fs).systemTempDirectory.createTempSync();
        }
      }

      String templateFilePath = join(cacheDir.path, file.template!.template!);

      templateFile = (fileSystem ?? fs).file(templateFilePath);
      templateFile?.createSync(recursive: true);
      templateFile?.writeAsStringSync(tContent);
    }
  }

  Future<void> call();

  Future<void> rollback();

  resolveModules() async {
    for (final action in action.actions) {
      if (allowedActions.contains(action.type)) {
        childModules.add(await _getModuleForAction(action));
      }
    }
  }

  executeModules() async {
    for (final module in childModules) {
      if (!isRollingBack) {
        try {
          logger.info('Applying action: ${module.action.type}');
          await module();
          logger.info('Action completed: ${module.action.type}');
        } catch (e) {
          logger.severe('Error executing module ${module.runtimeType}: $e');
          isRollingBack = true;
          await module.rollback();
        }
      } else {
        await module.rollback();
      }
    }
  }

  Future<ResourceModule> _getModuleForAction(Action action) async {
    return await getModuleForAction(file, action, fileSystem);
  }
}

Future<ResourceModule> getModuleForAction(ResourceModel file, Action action,
    [FileSystem? fs]) async {
  switch (action.type) {
    case 'backup':
      return FileBackupModule(file, action, fileSystem: fs);
    case 'copy':
      return FileCopyModule(file, action, fileSystem: fs);
    case 'symlink':
      return FileSymlinkModule(file, action, fileSystem: fs);
    case 'permissions':
      return FilePermissionModule(file, action, fileSystem: fs);
    case 'compress':
      return FileCompressModule(file, action, fileSystem: fs);
    case 'decompress':
      return FileDecompressModule(file, action, fileSystem: fs);
    case 'delete':
      return FileDeleteModule(file, action, fileSystem: fs);
    case 'download':
      return FileDownloadModule(file, action, fileSystem: fs);
    case 'validate':
      return FileValidateModule(file, action, fileSystem: fs);
    case 'rename':
      return FileRenameModule(file, action, fileSystem: fs);
    case 'execute':
      return FileExecuteModule(file, action, fileSystem: fs);
    case 'touch':
      return FileTouchModule(file, action, fileSystem: fs);
    default:
      throw Exception('Unknown action type: ${action.type}');
  }
}
