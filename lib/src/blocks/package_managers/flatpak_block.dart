import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/flatpak.dart';

import 'base_package_block.dart';

class FlatpakBlock extends BasePackageBlock {
  @override
  String get blockType => 'flatpak';

  @override
  PackageManager createManager() =>
      FlatpakPackageManager(di<PrivilegeEscalation>());
}
