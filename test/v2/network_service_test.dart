import 'dart:io' show ProcessResult;

import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/network_service.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutionNetworkService', () {
    test(
      'fails forced remote download clearly when curl is unavailable',
      () async {
        final service = ExecutionNetworkService(_FakeExecutionService({}));

        expect(
          () => service.downloadToFile(
            url: 'https://example.com/file',
            destinationPath: '/tmp/file',
            checksumAlgorithm: 'sha256',
            transferMode: DownloadTransferMode.remote,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Remote downloads require curl'),
            ),
          ),
        );
      },
    );

    test('auto download falls back to controller copy without curl', () async {
      final execution = _FakeExecutionService({});
      final controller = _FakeNetworkService(
        DownloadResult(checksum: 'abc123', receivedBytes: 7),
      );
      final service = ExecutionNetworkService(
        execution,
        controllerNetworkService: controller,
      );

      final result = await service.downloadToFile(
        url: 'https://example.com/file',
        destinationPath: '/tmp/file',
        checksumAlgorithm: 'sha256',
      );

      expect(result.checksum, equals('abc123'));
      expect(result.receivedBytes, equals(7));
      expect(controller.downloadedUrl, equals('https://example.com/file'));
      expect(execution.putDestination, equals('/tmp/file'));
    });

    test('uses target DNS tooling when probing DNS', () async {
      final service = ExecutionNetworkService(
        _FakeExecutionService({'getent'}, hosts: {'example.com': '192.0.2.10'}),
      );

      final result = await service.probeDns('example.com', timeoutSeconds: 5);

      expect(result.success, isTrue);
      expect(result.resolvedAddress, equals('192.0.2.10'));
    });

    test('uses target shell when probing ping on Unix', () async {
      final execution = _FakeExecutionService({'ping'});
      final service = ExecutionNetworkService(execution);

      final result = await service.probePing('example.com', timeoutSeconds: 5);

      expect(result.success, isTrue);
      expect(execution.lastCommand, endsWith('sh'));
      expect(execution.lastArguments, contains('-c'));
      expect(execution.lastArguments.join(' '), contains("'example.com'"));
    });
  });
}

class _FakeExecutionService implements ExecutionService {
  final Set<String> tools;
  final Map<String, String> hosts;
  String? putSource;
  String? putDestination;
  String? lastCommand;
  List<String> lastArguments = const [];

  _FakeExecutionService(this.tools, {this.hosts = const {}});

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
  Future<void> putFile(String sourcePath, String destinationPath) async {
    putSource = sourcePath;
    putDestination = destinationPath;
  }

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
    lastCommand = command;
    lastArguments = List<String>.from(arguments);
    final script = arguments.join(' ');
    if (script.contains('command -v')) {
      return ProcessResult(0, 0, '${tools.join('\n')}\n', '');
    }

    if (script.contains('getent hosts')) {
      final host = hosts.keys.firstWhere(script.contains, orElse: () => '');
      final address = hosts[host];
      if (address == null) return ProcessResult(0, 2, '', '');
      return ProcessResult(0, 0, '$address\n', '');
    }

    if (command.endsWith('sh') && script.contains('ping ')) {
      return ProcessResult(0, 0, '', '');
    }

    return ProcessResult(0, 127, '', 'unexpected command: $command $script');
  }
}

class _FakeNetworkService implements NetworkService {
  final DownloadResult downloadResult;
  String? downloadedUrl;

  _FakeNetworkService(this.downloadResult);

  @override
  Future<DownloadResult> downloadToFile({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    Map<String, String> headers = const {},
    bool resume = false,
    DownloadTransferMode transferMode = DownloadTransferMode.auto,
    DownloadProgressHandler? onProgress,
  }) async {
    downloadedUrl = url;
    onProgress?.call(
      downloadResult.receivedBytes,
      downloadResult.receivedBytes,
      'Downloading...',
    );
    return downloadResult;
  }

  @override
  Future<NetworkProbeResult> probeConnectivity(
    String source, {
    required int timeoutSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NetworkProbeResult> probeDns(
    String host, {
    required int timeoutSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NetworkProbeResult> probeHttp(NetworkRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<NetworkProbeResult> probePing(
    String host, {
    required int timeoutSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NetworkProbeResult> probeTcp(
    String host,
    int port, {
    required int timeoutSeconds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NetworkResponse> request(NetworkRequest request) {
    throw UnimplementedError();
  }
}
