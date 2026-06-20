import 'package:app_dirs/app_dirs.dart';
import 'package:file/local.dart';
import 'package:path/path.dart';

final fs = LocalFileSystem();
var dirs = Directories();

String resolveHomeDirectory(String pathStr) {
  if (pathStr.startsWith('~')) {
    final homeDir = dirs.baseDirs.home;
    return join(homeDir, pathStr.substring(2));
  }
  return pathStr;
}

final appDirs =
    dirs.appDirs(application: 'configr', preferUnixConventions: true);
