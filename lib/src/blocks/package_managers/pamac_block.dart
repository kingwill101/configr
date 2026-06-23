import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pamac.dart';

import 'base_package_block.dart';

class PamacBlock extends BasePackageBlock {
  @override
  String get blockType => 'pamac';

  @override
  PackageManager createManager() =>
      PamacPackageManager(di<PrivilegeEscalation>());
}
