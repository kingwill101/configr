import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/yum.dart';

import 'base_package_block.dart';

class YumBlock extends BasePackageBlock {
  @override
  String get blockType => 'yum';

  @override
  PackageManager createManager() =>
      YumPackageManager(di<PrivilegeEscalation>());
}
