import 'package:configr/src/di.dart';
import 'package:configr/src/package_management/package_manger.dart';
import 'package:configr/src/package_management/pip.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:i3config/i3config_v2.dart' as i3;

import 'base_package_block.dart';

class PipBlock extends BasePackageBlock {
  @override
  String get blockType => 'pip';

  String? venv;
  String? requirements;

  @override
  PackageManager createManager() =>
      PipPackageManager(di<PrivilegeEscalation>());

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    venv = context.getVariable('venv') as String?;
    requirements = context.getVariable('requirements') as String?;
  }

  @override
  void resetState() {
    super.resetState();
    venv = null;
    requirements = null;
  }

  @override
  Future<void> execute() async {
    if (venv != null) {
      await runCommand('python3', ['-m', 'venv', venv!]);
    }
    await super.execute();
    if (requirements != null) {
      await runCommand('pip3', ['install', '-r', requirements!]);
    }
  }

  @override
  Map<String, String> get additionalProperties => {
    ...super.additionalProperties,
    if (venv != null) 'venv': venv!,
    if (requirements != null) 'requirements': requirements!,
  };
}
