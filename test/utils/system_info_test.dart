import 'package:configr/src/utils/system_info.dart';
import 'package:configr/src/utils/target_system.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:test/test.dart';

void main() {
  test('uses target facts when kernel and fqdn fields are empty', () {
    final facts = TargetSystemFacts(
      os: OperatingSystem.linux,
      family: OsFamily.debian,
      distribution: 'ubuntu',
      distributionVersion: '6.9.1-target',
      architecture: 'x86_64',
      hostname: 'target-host',
    );

    final info = SystemInfo(configDir: '/tmp/configr', targetFacts: facts);

    expect(info.osKernel, equals('6.9.1-target'));
    expect(info.hostFqdn, equals('target-host'));
  });
}
