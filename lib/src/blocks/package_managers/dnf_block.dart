import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/dnf.dart';

import 'base_package_block.dart';

class DnfBlock extends BasePackageBlock {
  @override
  String get blockType => 'dnf';

  @override
  PackageManager createManager() =>
      DnfPackageManager(di<PrivilegeEscalation>());
}
