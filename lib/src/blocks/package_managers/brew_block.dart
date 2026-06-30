import 'package:configr/src/di.dart';
import 'package:configr/src/package_management/brew.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

import 'base_package_block.dart';

class BrewBlock extends BasePackageBlock {
  @override
  String get blockType => 'brew';

  @override
  PackageManager createManager() =>
      BrewPackageManager(di<PrivilegeEscalation>());
}
