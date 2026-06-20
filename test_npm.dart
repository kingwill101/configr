import 'package:configr/package_management/npm.dart';
import 'package:configr/utils/privellage_escallation.dart';

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

