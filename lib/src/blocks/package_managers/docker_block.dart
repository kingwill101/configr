import 'package:configr/src/di.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/docker.dart';

import 'base_package_block.dart';

class DockerBlock extends BasePackageBlock {
  @override
  String get blockType => 'docker';

  @override
  PackageManager createManager() =>
      DockerPackageManager(di<PrivilegeEscalation>());
}
