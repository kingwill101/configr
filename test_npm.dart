import 'package:configr/src/package_management/npm.dart';
import 'package:configr/src/utils/privilege_escalation.dart';

void main() async {
  final noPrivilege = InteractiveSudoEscalation();
  final npm = NpmPackageManager(noPrivilege);

  try {
    print('Testing npm availability...');
    final isAvailable = await npm.isAvailable();
    print('npm is available: $isAvailable');

    if (isAvailable) {
      print('Testing npm isInstalled...');
      final isInstalled = await npm.isInstalled('lodash');
      print('lodash is installed: $isInstalled');
    }
  } catch (e) {
    print('Error: $e');
  }
}
