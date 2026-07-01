import 'dart:convert';
import 'dart:typed_data';

import 'package:configr/src/strategies/script_strategy.dart';
import 'package:configr/src/utils/shell_type.dart';
import 'package:test/test.dart';

void main() {
  test('PowerShell script args use encoded commands', () {
    final args = ShellType.powershell.scriptArgs(
      r"New-Item -ItemType Directory -Force -Path 'C:\temp\configr demo'",
    );

    expect(args, hasLength(3));
    expect(args[0], equals('-NoProfile'));
    expect(args[1], equals('-EncodedCommand'));
    expect(_decodePowerShell(args[2]), contains('New-Item'));
    expect(_decodePowerShell(args[2]), contains(r'C:\temp\configr demo'));
  });

  test('Windows script strategy runs inline scripts through PowerShell', () {
    final strategy = ScriptStrategy.forPlatform('windows');
    final (executable, args) = strategy.runScript("Write-Host 'ok'");

    expect(executable, equals('powershell'));
    expect(args, contains('-EncodedCommand'));
    expect(_decodePowerShell(args.last), equals("Write-Host 'ok'"));
  });

  test('Unix script strategy keeps POSIX sh command shape', () {
    final strategy = ScriptStrategy.forPlatform('linux');
    final (executable, args) = strategy.runScript('echo ok');

    expect(executable, equals('/bin/sh'));
    expect(args, equals(['-c', 'echo ok']));
  });
}

String _decodePowerShell(String encoded) {
  final bytes = base64Decode(encoded);
  final units = Uint16List(bytes.length ~/ 2);
  for (var i = 0; i < units.length; i++) {
    units[i] = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
  }
  return String.fromCharCodes(units);
}
