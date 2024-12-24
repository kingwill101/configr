import 'package:configr/utils/fs.dart';
import 'package:path/path.dart';

extension StringExtension on String {
  String unescape() {
    return replaceAll(RegExp(r'\\'), '');
  }

  String unquote() {
    return replaceAll(RegExp('["\']'), '');
  }

  normalizePath() {
    return normalize(resolveHomeDirectory(this));
  }

  String clean() {
    return unescape().unquote();
  }
}
