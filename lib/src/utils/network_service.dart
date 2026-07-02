import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:configr/src/strategies/network_strategy.dart';
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
  final NetworkStrategy _strategy;
  final NetworkService controllerNetworkService;
  Future<_RemoteNetworkCapabilities>? _capabilities;

  ExecutionNetworkService(
    this.executionService, {
    NetworkService? controllerNetworkService,
  }) : _strategy = NetworkStrategy.forPlatform(executionService.platform),
       controllerNetworkService =
           controllerNetworkService ?? const LocalNetworkService();

  Future<_RemoteNetworkCapabilities> get _remoteCapabilities {
    return _capabilities ??= _RemoteNetworkCapabilities.detect(
      executionService,
      _strategy,
    );
  }

  @override
  Future<NetworkResponse> request(NetworkRequest request) async {
    final cmd = _strategy.httpRequestScript(request);
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
    );
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
    final canDownload = await _canDownloadRemotely;
    if (transferMode == DownloadTransferMode.remote && !canDownload) {
      throw StateError('Remote downloads require curl on the target host.');
    }
    if (transferMode == DownloadTransferMode.controller ||
        (transferMode == DownloadTransferMode.auto && !canDownload)) {
      return _downloadViaController(
        url: url,
        destinationPath: destinationPath,
        checksumAlgorithm: checksumAlgorithm,
        headers: headers,
        resume: resume,
        onProgress: onProgress,
      );
    }

    final cmd = _strategy.downloadScript(
      url: url,
      destinationPath: destinationPath,
      checksumAlgorithm: checksumAlgorithm,
      headers: headers,
      resume: resume,
    );

    var checksum = '';
    var receivedBytes = 0;
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
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
    final start = DateTime.now();
    final cmd = _strategy.dnsResolveScript(host);
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
    );
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
    final start = DateTime.now();
    final cmd = _strategy.pingProbeScript(host, timeoutSeconds);
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
    );
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
    final cmd = _strategy.tcpProbeScript(host, port, timeoutSeconds);
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
    );
    return NetworkProbeResult(
      success: result.exitCode == 0,
      elapsedMs: _elapsed(start),
    );
  }

  Future<bool> get _canDownloadRemotely async {
    if (executionService.platform.toLowerCase().contains('windows')) {
      return true;
    }
    final caps = await _remoteCapabilities;
    return caps.hasCurl;
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

Map<String, dynamic>? _tryJson(String line) {
  try {
    final decoded = jsonDecode(line);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

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
    NetworkStrategy strategy,
  ) async {
    final cmd = strategy.capabilityDetectionScript();
    final result = await executionService.run(
      cmd.executable,
      cmd.args,
      stdin: cmd.stdin,
    );
    final lines = result.stdout
        .toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);

    final tools = <String>{};
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length == 2 && parts[1].trim() == 'yes') {
        tools.add(parts[0].trim());
      }
    }

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
