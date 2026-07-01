import 'dart:convert';
import 'dart:io';

import 'package:configr/src/utils/execution_service.dart';
import 'package:test/test.dart';

void main() {
  test(
    'AuditedExecutionService writes shell call and response records',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('configr_audit_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = AuditedExecutionService(
        delegate: _FakeExecutionService(),
        logDirectory: tempDir.path,
        sessionId: 'test-session',
      );

      final result = await service.run(
        'echo',
        ['hello'],
        workingDirectory: '/work',
        environment: {'TOKEN': 'secret-value', 'PLAIN': 'visible'},
        stdin: 'input',
      );

      expect(result.exitCode, 0);

      final logFile = File('${tempDir.path}/shell-test-session.jsonl');
      expect(await logFile.exists(), isTrue);

      final records = (await logFile.readAsLines())
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();

      expect(records, hasLength(2));
      expect(records[0]['event'], 'shell_call');
      expect(records[0]['command'], 'echo');
      expect(records[0]['arguments'], ['hello']);
      expect(records[0]['workingDirectory'], '/work');
      expect(records[0]['stdin'], 'input');
      expect(records[0]['environment'], {
        'TOKEN': '<redacted>',
        'PLAIN': 'visible',
      });

      expect(records[1]['event'], 'shell_response');
      expect(records[1]['exitCode'], 0);
      expect(records[1]['stdout'], 'hello\n');
      expect(records[1]['stderr'], '');
      expect(records[1]['durationMs'], isA<int>());
    },
  );
}

class _FakeExecutionService implements ExecutionService {
  @override
  String get platform => 'linux';

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(Map<String, dynamic> config) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {}

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {}

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  }) async {
    return ProcessResult(42, 0, 'hello\n', '');
  }
}
