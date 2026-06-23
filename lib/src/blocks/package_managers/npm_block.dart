import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/npm.dart';

import 'base_package_block.dart';

class NpmBlock extends BasePackageBlock {
  @override
  String get blockType => 'npm';

  @override
  PackageManager createManager() =>
      NpmPackageManager(di<PrivilegeEscalation>());
}
