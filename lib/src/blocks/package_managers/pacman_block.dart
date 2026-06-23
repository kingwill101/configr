import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pacman.dart';

import 'base_package_block.dart';

class PacmanBlock extends BasePackageBlock {
  @override
  String get blockType => 'pacman';

  @override
  PackageManager createManager() =>
      PacmanPackageManager(di<PrivilegeEscalation>());
}
