import 'package:configr/src/di.dart';
import 'package:configr/src/package_management/apt.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

import 'base_package_block.dart';

class AptBlock extends BasePackageBlock {
  @override
  String get blockType => 'apt';

  @override
  PackageManager createManager() =>
      AptPackageManager(di<PrivilegeEscalation>());
}
