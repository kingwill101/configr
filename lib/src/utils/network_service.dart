import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/utils/execution_service.dart';
import 'package:crypto/crypto.dart' show md5, sha1, sha256;
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;
import 'package:http/http.dart' as http;

typedef DownloadProgressHandler =
    void Function(int receivedBytes, int totalBytes, String message);

class NetworkRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
  final int timeoutSeconds;
  final bool validateCertificates;

  const NetworkRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body = '',
    this.timeoutSeconds = 30,
    this.validateCertificates = true,
  });
}

class NetworkResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const NetworkResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}

class DownloadResult {
  final String checksum;
  final int receivedBytes;

  const DownloadResult({required this.checksum, required this.receivedBytes});
}

enum DownloadTransferMode {
  auto,
  remote,
  controller;

  static DownloadTransferMode parse(String value) {
    return switch (value.toLowerCase().trim()) {
      'auto' => DownloadTransferMode.auto,
      'remote' || 'direct' || 'target' => DownloadTransferMode.remote,
      'controller' || 'host' || 'local' => DownloadTransferMode.controller,
      _ => throw ArgumentError.value(value, 'value', 'Unknown transfer mode'),
    };
  }
}

class NetworkProbeResult {
  final bool success;
  final int elapsedMs;
  final int? statusCode;
  final String? body;
  final String? resolvedAddress;
  final Map<String, String> headers;

  const NetworkProbeResult({
    required this.success,
    required this.elapsedMs,
    this.statusCode,
    this.body,
    this.resolvedAddress,
    this.headers = const {},
  });
}

abstract class NetworkService {
  Future<NetworkResponse> request(NetworkRequest request);

  Future<DownloadResult> downloadToFile({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    Map<String, String> headers = const {},
    bool resume = false,
    DownloadTransferMode transferMode = DownloadTransferMode.auto,
    DownloadProgressHandler? onProgress,
  });

  Future<NetworkProbeResult> probeHttp(NetworkRequest request);

  Future<NetworkProbeResult> probeConnectivity(
    String source, {
    required int timeoutSeconds,
  });

  Future<NetworkProbeResult> probeTcp(
    String host,
    int port, {
    required int timeoutSeconds,
  });

  Future<NetworkProbeResult> probeDns(
    String host, {
    required int timeoutSeconds,
  });

  Future<NetworkProbeResult> probePing(
    String host, {
    required int timeoutSeconds,
  });
}

class LocalNetworkService implements NetworkService {
  final FileSystem fileSystem;

  const LocalNetworkService({this.fileSystem = const LocalFileSystem()});

  @override
  Future<NetworkResponse> request(NetworkRequest request) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: request.timeoutSeconds);

    if (!request.validateCertificates) {
      client.badCertificateCallback = (_, _, _) => true;
    }

    try {
      final httpRequest = await client.openUrl(request.method, request.uri);
      for (final entry in request.headers.entries) {
        httpRequest.headers.set(entry.key, entry.value);
      }

      if (request.body.isNotEmpty &&
          request.method != 'GET' &&
          request.method != 'HEAD') {
        httpRequest.write(request.body);
      }

      final response = await httpRequest.close().timeout(
        Duration(seconds: request.timeoutSeconds),
      );
      final body = await response.transform(utf8.decoder).join();
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });

      return NetworkResponse(
        statusCode: response.statusCode,
        headers: responseHeaders,
        body: body,
      );
    } finally {
      client.close(force: true);
    }
  }

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
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);

      var isResumed = false;
      final destination = fileSystem.file(destinationPath);
      if (resume && await destination.exists()) {
        final resumePosition = await destination.length();
        request.headers['Range'] = 'bytes=$resumePosition-';
        isResumed = true;
      }

      final response = await client.send(request);
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw StateError('Failed to download: HTTP ${response.statusCode}');
      }

      final sink = destination.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );
      var receivedBytes = 0;
      final totalBytes = response.contentLength ?? -1;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(
            receivedBytes,
            totalBytes,
            isResumed ? 'Resuming download...' : 'Downloading...',
          );
        }
      } finally {
        await sink.close();
      }

      return DownloadResult(
        checksum: _calculateChecksum(
          await destination.readAsBytes(),
          checksumAlgorithm,
        ),
        receivedBytes: receivedBytes,
      );
    } finally {
      client.close();
    }
  }

  @override
  Future<NetworkProbeResult> probeConnectivity(
    String source, {
    required int timeoutSeconds,
  }) async {
    final start = DateTime.now();
    try {
      final result = await InternetAddress.lookup(
        Uri.parse(source).host,
      ).timeout(Duration(seconds: timeoutSeconds));
      return NetworkProbeResult(
        success: result.isNotEmpty,
        elapsedMs: _elapsed(start),
        resolvedAddress: result.isEmpty ? null : result.first.address,
      );
    } on SocketException {
      return NetworkProbeResult(success: false, elapsedMs: _elapsed(start));
    }
  }

  @override
  Future<NetworkProbeResult> probeDns(
    String host, {
    required int timeoutSeconds,
  }) async {
    final start = DateTime.now();
    try {
      final results = await InternetAddress.lookup(
        host,
      ).timeout(Duration(seconds: timeoutSeconds));
      return NetworkProbeResult(
        success: results.isNotEmpty,
        elapsedMs: _elapsed(start),
        resolvedAddress: results.isEmpty ? null : results.first.address,
      );
    } on SocketException {
      return NetworkProbeResult(success: false, elapsedMs: _elapsed(start));
    }
  }

  @override
  Future<NetworkProbeResult> probeHttp(NetworkRequest request) async {
    final start = DateTime.now();
    final response = await this.request(request);
    return NetworkProbeResult(
      success: response.statusCode >= 200 && response.statusCode < 400,
      elapsedMs: _elapsed(start),
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  Future<NetworkProbeResult> probePing(
    String host, {
    required int timeoutSeconds,
  }) async {
    final start = DateTime.now();
    final result = await Process.run('ping', [
      '-c',
      '1',
      '-W',
      timeoutSeconds.toString(),
      host,
    ]);
    return NetworkProbeResult(
      success: result.exitCode == 0,
      elapsedMs: _elapsed(start),
    );
  }

  @override
  Future<NetworkProbeResult> probeTcp(
    String host,
    int port, {
    required int timeoutSeconds,
  }) async {
    final start = DateTime.now();
    try {
      final socket = await Socket.connect(
        host,
        port,
      ).timeout(Duration(seconds: timeoutSeconds));
      await socket.close();
      return NetworkProbeResult(success: true, elapsedMs: _elapsed(start));
    } on SocketException {
      return NetworkProbeResult(success: false, elapsedMs: _elapsed(start));
    }
  }
}

class ExecutionNetworkService implements NetworkService {
  final ExecutionService executionService;
  final NetworkService controllerNetworkService;
  Future<_RemoteNetworkCapabilities>? _capabilities;

  ExecutionNetworkService(
    this.executionService, {
    NetworkService? controllerNetworkService,
  }) : controllerNetworkService =
           controllerNetworkService ?? const LocalNetworkService();

  Future<_RemoteNetworkCapabilities> get _remoteCapabilities {
    return _capabilities ??= _RemoteNetworkCapabilities.detect(
      executionService,
    );
  }

  @override
  Future<NetworkResponse> request(NetworkRequest request) async {
    _throwIfWindowsRemote('HTTP requests');

    final caps = await _remoteCapabilities;
    if (!caps.hasCurl) {
      throw StateError(
        'Remote HTTP requests require curl on the target host. '
        'Install curl or run this block locally.',
      );
    }

    final bodyPath =
        '/tmp/configr_uri_${DateTime.now().microsecondsSinceEpoch}';
    final headers = _curlHeaderArgs(request.headers);
    final command = StringBuffer()
      ..write('status=\$(curl -sS -m ${request.timeoutSeconds} ')
      ..write(request.validateCertificates ? '' : '-k ')
      ..write('-X ${_sh(request.method)} ')
      ..write(headers)
      ..write(request.body.isEmpty ? '' : '--data-binary ${_sh(request.body)} ')
      ..write('-o ${_sh(bodyPath)} -w "%{http_code}" ')
      ..write(_sh(request.uri.toString()))
      ..write(
        '); code=\$?; body=\$(cat ${_sh(bodyPath)} 2>/dev/null || true); ',
      )
      ..write('rm -f ${_sh(bodyPath)}; ')
      ..write('printf "%s\\n%s" "\$status" "\$body"; exit "\$code"');

    final result = await executionService.run('sh', ['-c', command.toString()]);
    if (result.exitCode != 0) {
      throw StateError('Remote request failed: ${result.stderr}');
    }
    final output = result.stdout.toString();
    final newline = output.indexOf('\n');
    final status = int.tryParse(
      (newline == -1 ? output : output.substring(0, newline)).trim(),
    );
    return NetworkResponse(
      statusCode: status ?? 0,
      headers: const {},
      body: newline == -1 ? '' : output.substring(newline + 1),
    );
  }

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
    final caps = await _remoteCapabilities;

    if (transferMode == DownloadTransferMode.controller ||
        transferMode == DownloadTransferMode.auto &&
            !_canDownloadRemotely(caps, checksumAlgorithm)) {
      return _downloadViaController(
        url: url,
        destinationPath: destinationPath,
        checksumAlgorithm: checksumAlgorithm,
        headers: headers,
        resume: resume,
        onProgress: onProgress,
      );
    }

    if (!caps.hasCurl) {
      throw StateError(
        'Remote downloads require curl on the target host. '
        'Install curl to download directly on the remote host, or set '
        'transfer_mode = "controller" to download on the controller and copy.',
      );
    }

    final hashCommand = caps.hashCommand(checksumAlgorithm);
    if (hashCommand == null) {
      throw StateError(
        'Remote checksum verification requires ${checksumAlgorithm.toLowerCase()}sum '
        'or openssl on the target host, or set transfer_mode = "controller".',
      );
    }
    final tempPath =
        '$destinationPath.configr-download-${DateTime.now().microsecondsSinceEpoch}.tmp';
    final headerArgs = _curlHeaderArgs(headers);
    final continueArg = resume ? '-C - ' : '';
    final resumeFlag = resume ? '1' : '0';
    final script =
        '''
set -eu
url=${_sh(url)}
dest=${_sh(destinationPath)}
tmp=${_sh(tempPath)}
mkdir -p "\$(dirname "\$dest")"
if [ $resumeFlag -eq 1 ] && [ -f "\$dest" ]; then
  cp "\$dest" "\$tmp"
fi
total=\$(curl -fsIL ${requestTimeoutFlag(30)} $headerArgs "\$url" 2>/dev/null | awk 'tolower(\$1)=="content-length:" {gsub("\\r","",\$2); print \$2}' | tail -n 1 || true)
(curl -fL ${requestTimeoutFlag(0)} $continueArg $headerArgs --output "\$tmp" "\$url") &
pid=\$!
while kill -0 "\$pid" 2>/dev/null; do
  size=\$(wc -c < "\$tmp" 2>/dev/null || echo 0)
  printf '{"bytes":%s,"total":%s}\\n' "\$size" "\${total:-0}"
  sleep 1
done
wait "\$pid"
mv "\$tmp" "\$dest"
size=\$(wc -c < "\$dest" 2>/dev/null || echo 0)
checksum=\$($hashCommand "\$dest" | awk '{print \$1}')
printf '{"complete":true,"bytes":%s,"checksum":"%s"}\\n' "\$size" "\$checksum"
''';

    var checksum = '';
    var receivedBytes = 0;
    final result = await executionService.run(
      'sh',
      ['-s'],
      stdin: script,
      onOutput: (line, isStderr) {
        if (isStderr) return;
        final parsed = _tryJson(line);
        if (parsed == null) return;
        final bytes = parsed['bytes'];
        if (bytes is int) receivedBytes = bytes;
        if (parsed['complete'] == true) {
          checksum = parsed['checksum']?.toString() ?? '';
          return;
        }
        final total = parsed['total'];
        onProgress?.call(
          bytes is int ? bytes : 0,
          total is int ? total : -1,
          resume ? 'Resuming remote download...' : 'Downloading remotely...',
        );
      },
    );

    if (result.exitCode != 0) {
      throw StateError('Remote download failed: ${result.stderr}');
    }

    return DownloadResult(checksum: checksum, receivedBytes: receivedBytes);
  }

  Future<DownloadResult> _downloadViaController({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    required Map<String, String> headers,
    required bool resume,
    required DownloadProgressHandler? onProgress,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('configr-download-');
    final tempPath = '${tempDir.path}${Platform.pathSeparator}payload';
    try {
      final result = await controllerNetworkService.downloadToFile(
        url: url,
        destinationPath: tempPath,
        checksumAlgorithm: checksumAlgorithm,
        headers: headers,
        resume: resume,
        transferMode: DownloadTransferMode.controller,
        onProgress: onProgress,
      );
      onProgress?.call(
        result.receivedBytes,
        result.receivedBytes,
        'Copying download to remote...',
      );
      await executionService.putFile(tempPath, destinationPath);
      return result;
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  @override
  Future<NetworkProbeResult> probeConnectivity(
    String source, {
    required int timeoutSeconds,
  }) {
    return probeDns(Uri.parse(source).host, timeoutSeconds: timeoutSeconds);
  }

  @override
  Future<NetworkProbeResult> probeDns(
    String host, {
    required int timeoutSeconds,
  }) async {
    _throwIfWindowsRemote('DNS probes');

    final caps = await _remoteCapabilities;
    final start = DateTime.now();
    final command = caps.hasGetent
        ? 'getent hosts ${_sh(host)} | awk \'{print \$1; exit}\''
        : caps.hasNslookup
        ? 'nslookup ${_sh(host)} | awk \'/^Address: / {print \$2; exit}\''
        : caps.hasHost
        ? 'host ${_sh(host)} | awk \'/has address/ {print \$4; exit}\''
        : null;
    if (command == null) {
      throw StateError(
        'Remote DNS probes require one of: getent, nslookup, host.',
      );
    }
    final result = await executionService.run('sh', ['-c', command]);
    final address = result.stdout.toString().trim();
    return NetworkProbeResult(
      success: result.exitCode == 0 && address.isNotEmpty,
      elapsedMs: _elapsed(start),
      resolvedAddress: address.isEmpty ? null : address,
    );
  }

  @override
  Future<NetworkProbeResult> probeHttp(NetworkRequest request) async {
    final start = DateTime.now();
    final response = await this.request(request);
    return NetworkProbeResult(
      success: response.statusCode >= 200 && response.statusCode < 400,
      elapsedMs: _elapsed(start),
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  Future<NetworkProbeResult> probePing(
    String host, {
    required int timeoutSeconds,
  }) async {
    _throwIfWindowsRemote('ping probes');

    final caps = await _remoteCapabilities;
    if (!caps.hasPing) {
      throw StateError('Remote ping probes require ping on the target host.');
    }

    final start = DateTime.now();
    final result = await executionService.run('ping', [
      '-c',
      '1',
      '-W',
      timeoutSeconds.toString(),
      host,
    ]);
    return NetworkProbeResult(
      success: result.exitCode == 0,
      elapsedMs: _elapsed(start),
    );
  }

  @override
  Future<NetworkProbeResult> probeTcp(
    String host,
    int port, {
    required int timeoutSeconds,
  }) async {
    _throwIfWindowsRemote('TCP probes');

    final caps = await _remoteCapabilities;
    final start = DateTime.now();
    final command = caps.hasNc
        ? 'nc -z -w ${_sh(timeoutSeconds.toString())} ${_sh(host)} ${_sh(port.toString())}'
        : caps.hasTimeout
        ? 'timeout ${_sh(timeoutSeconds.toString())} sh -c ${_sh('echo >/dev/tcp/$host/$port')}'
        : null;
    if (command == null) {
      throw StateError(
        'Remote TCP probes require nc, or timeout plus /dev/tcp shell support.',
      );
    }
    final result = await executionService.run('sh', ['-c', command]);
    return NetworkProbeResult(
      success: result.exitCode == 0,
      elapsedMs: _elapsed(start),
    );
  }

  bool _canDownloadRemotely(
    _RemoteNetworkCapabilities caps,
    String checksumAlgorithm,
  ) {
    return !_isWindowsRemote &&
        caps.hasCurl &&
        caps.hashCommand(checksumAlgorithm) != null;
  }

  bool get _isWindowsRemote =>
      executionService.platform.toLowerCase().contains('windows');

  void _throwIfWindowsRemote(String operation) {
    if (!_isWindowsRemote) return;
    throw StateError(
      'Remote $operation on Windows targets requires a PowerShell/.NET network '
      'backend. Use download transfer_mode = "controller" for file downloads.',
    );
  }
}

String _calculateChecksum(List<int> bytes, String algorithm) {
  switch (algorithm.toLowerCase()) {
    case 'md5':
      return md5.convert(bytes).toString();
    case 'sha1':
      return sha1.convert(bytes).toString();
    case 'sha256':
    default:
      return sha256.convert(bytes).toString();
  }
}

String _curlHeaderArgs(Map<String, String> headers) {
  return headers.entries
      .map((entry) => '-H ${_sh('${entry.key}: ${entry.value}')} ')
      .join();
}

Map<String, dynamic>? _tryJson(String line) {
  try {
    final decoded = jsonDecode(line);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

String _sh(String value) {
  if (value.isEmpty) return "''";
  return "'${value.replaceAll("'", "'\\''")}'";
}

String requestTimeoutFlag(int seconds) => seconds <= 0 ? '' : '-m $seconds';

int _elapsed(DateTime start) => DateTime.now().difference(start).inMilliseconds;

class _RemoteNetworkCapabilities {
  final bool hasCurl;
  final bool hasGetent;
  final bool hasHost;
  final bool hasMd5sum;
  final bool hasNc;
  final bool hasNslookup;
  final bool hasOpenssl;
  final bool hasPing;
  final bool hasSha1sum;
  final bool hasSha256sum;
  final bool hasTimeout;

  const _RemoteNetworkCapabilities({
    required this.hasCurl,
    required this.hasGetent,
    required this.hasHost,
    required this.hasMd5sum,
    required this.hasNc,
    required this.hasNslookup,
    required this.hasOpenssl,
    required this.hasPing,
    required this.hasSha1sum,
    required this.hasSha256sum,
    required this.hasTimeout,
  });

  String? hashCommand(String algorithm) {
    return switch (algorithm.toLowerCase()) {
      'md5' when hasMd5sum => 'md5sum',
      'md5' when hasOpenssl => 'openssl dgst -md5 -r',
      'sha1' when hasSha1sum => 'sha1sum',
      'sha1' when hasOpenssl => 'openssl dgst -sha1 -r',
      'sha256' when hasSha256sum => 'sha256sum',
      'sha256' when hasOpenssl => 'openssl dgst -sha256 -r',
      _ => null,
    };
  }

  static Future<_RemoteNetworkCapabilities> detect(
    ExecutionService executionService,
  ) async {
    final result = await executionService.run('sh', [
      '-c',
      [
            'curl',
            'getent',
            'host',
            'md5sum',
            'nc',
            'nslookup',
            'openssl',
            'ping',
            'sha1sum',
            'sha256sum',
            'timeout',
          ]
          .map((tool) => 'command -v $tool >/dev/null 2>&1 && echo $tool')
          .join('; '),
    ]);
    final tools = result.stdout
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();

    return _RemoteNetworkCapabilities(
      hasCurl: tools.contains('curl'),
      hasGetent: tools.contains('getent'),
      hasHost: tools.contains('host'),
      hasMd5sum: tools.contains('md5sum'),
      hasNc: tools.contains('nc'),
      hasNslookup: tools.contains('nslookup'),
      hasOpenssl: tools.contains('openssl'),
      hasPing: tools.contains('ping'),
      hasSha1sum: tools.contains('sha1sum'),
      hasSha256sum: tools.contains('sha256sum'),
      hasTimeout: tools.contains('timeout'),
    );
  }
}
