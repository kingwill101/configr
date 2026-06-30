import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/snap.dart';

import 'base_package_block.dart';

class SnapBlock extends BasePackageBlock {
  @override
  String get blockType => 'snap';

  @override
  PackageManager createManager() =>
      SnapPackageManager(di<PrivilegeEscalation>());
}
