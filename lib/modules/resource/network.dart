import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';

/// Network connectivity testing and management module.
/// 
/// Features:
/// - HTTP/HTTPS connectivity testing
/// - TCP/UDP port connectivity testing
/// - DNS resolution testing
/// - Network latency measurement
/// - HTTP response validation
/// - Custom headers and authentication
/// - Connection timeout management
/// - Network interface monitoring
/// - Proxy support
/// - SSL/TLS certificate validation
class FileNetworkModule extends ResourceModule {
  // State getters
  String get host => state['host'] as String? ?? '';
  int get port => state['port'] as int? ?? 80;
  String get protocol => state['protocol'] as String? ?? 'http';
  String get path => state['path'] as String? ?? '/';
  bool get connectivitySuccess => state['connectivitySuccess'] as bool? ?? false;
  int get responseCode => state['responseCode'] as int? ?? -1;
  String? get responseBody => state['responseBody'] as String?;
  Duration get responseTime => Duration(milliseconds: state['responseTime'] as int? ?? 0);

  // Enhanced features
  Duration get timeout => Duration(seconds: state['timeout'] as int? ?? 30);
  Map<String, String> get headers => Map<String, String>.from(state['headers'] as Map<String, dynamic>? ?? {});
  String? get username => state['username'] as String?;
  String? get password => state['password'] as String?;
  String? get proxyHost => state['proxyHost'] as String?;
  int get proxyPort => state['proxyPort'] as int? ?? 8080;
  String? get proxyUsername => state['proxyUsername'] as String?;
  String? get proxyPassword => state['proxyPassword'] as String?;
  bool get followRedirects => state['followRedirects'] as bool? ?? true;
  int get maxRedirects => state['maxRedirects'] as int? ?? 5;
  bool get validateCertificate => state['validateCertificate'] as bool? ?? true;
  String get method => state['method'] as String? ?? 'GET';
  String? get requestBody => state['requestBody'] as String?;
  String get contentType => state['contentType'] as String? ?? 'application/json';
  Map<String, String> get queryParams => Map<String, String>.from(state['queryParams'] as Map<String, dynamic>? ?? {});
  bool get expectSuccess => state['expectSuccess'] as bool? ?? true;
  List<int> get expectedStatusCodes => List<int>.from(state['expectedStatusCodes'] as List<dynamic>? ?? [200, 201, 202, 204]);
  String? get expectedContentType => state['expectedContentType'] as String?;
  String? get expectedText => state['expectedText'] as String?;
  Duration get operationDuration => Duration(milliseconds: state['operationDuration'] as int? ?? 0);
  String? get operationOutput => state['operationOutput'] as String?;
  String? get operationError => state['operationError'] as String?;
  int get dnsResolutionTime => state['dnsResolutionTime'] as int? ?? -1;
  String? get resolvedIP => state['resolvedIP'] as String?;

  FileNetworkModule(super.file, super.action,
      {super.allowedActions = const ['network'], super.fileSystem}) {
    updateState({
      'host': '',
      'port': 80,
      'protocol': 'http',
      'path': '/',
      'connectivitySuccess': false,
      'responseCode': -1,
      'responseBody': null,
      'responseTime': 0,
      'timeout': 30,
      'headers': <String, String>{},
      'username': null,
      'password': null,
      'proxyHost': null,
      'proxyPort': 8080,
      'proxyUsername': null,
      'proxyPassword': null,
      'followRedirects': true,
      'maxRedirects': 5,
      'validateCertificate': true,
      'method': 'GET',
      'requestBody': null,
      'contentType': 'application/json',
      'queryParams': <String, String>{},
      'expectSuccess': true,
      'expectedStatusCodes': [200, 201, 202, 204],
      'expectedContentType': null,
      'expectedText': null,
      'operationDuration': 0,
      'operationOutput': null,
      'operationError': null,
      'dnsResolutionTime': -1,
      'resolvedIP': null,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Starting network operation'));
    
    // Parse configuration
    final config = _parseConfiguration();
    updateState({
      'host': action.properties['host'] as String? ?? '',
      'port': int.tryParse(action.properties['port']?.toString() ?? '') ?? 80,
      'protocol': action.properties['protocol'] as String? ?? 'http',
      'path': action.properties['path'] as String? ?? '/',
      ...config,
    });

    await executeModules();
    if (isRollingBack) {
      return;
    }

    if (host.isEmpty) {
      throw ActionFailedException('Host is required for network operations', moduleId: action.id);
    }

    final startTime = DateTime.now();
    try {
      final operation = action.properties['operation'] as String? ?? 'connectivity';
      
      switch (operation) {
        case 'connectivity':
          await _executeConnectivity();
          break;
        case 'http':
          await _executeHttp();
          break;
        case 'tcp':
          await _executeTcp();
          break;
        case 'udp':
          await _executeUdp();
          break;
        case 'dns':
          await _executeDns();
          break;
        case 'ping':
          await _executePing();
          break;
        case 'port_scan':
          await _executePortScan();
          break;
        default:
          throw ActionFailedException('Unknown network operation: $operation', moduleId: action.id);
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      updateState({'operationDuration': duration.inMilliseconds});

      logger.info('Network operation completed successfully: $operation');
      emitEvent(CompletedEvent(moduleId: action.id, message: 'Network operation $operation completed successfully in ${duration.inMilliseconds}ms'));
    } catch (e, s) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      updateState({
        'error': e.toString(),
        'stackTrace': s.toString(),
        'operationDuration': duration.inMilliseconds,
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Network operation failed: ${e.toString()}'));
      throw ActionFailedException('Failed to execute network operation: ${e.toString()}', moduleId: action.id, cause: e, stackTrace: s);
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    emitEvent(StartedEvent(moduleId: action.id, message: 'Rolling back network operation'));
    
    try {
      logger.warning('Network operations cannot be rolled back');
      updateState({'rollbackAttempted': true});

      for (var module in childModules) {
        await module.rollback();
      }

      emitEvent(CompletedEvent(moduleId: action.id, message: 'Network rollback completed (no-op)'));
      await saveState();
    } catch (e, st) {
      updateState({
        'rollbackError': e.toString(),
        'rollbackStackTrace': st.toString()
      });
      emitEvent(FailedEvent(moduleId: action.id, message: 'Network rollback failed: ${e.toString()}'));
      rethrow;
    }
  }

  /// Parse configuration from action properties.
  Map<String, dynamic> _parseConfiguration() {
    final headers = <String, String>{};
    
    // Parse headers
    if (action.properties.containsKey('headers')) {
      final headersData = action.properties['headers'];
      if (headersData is Map) {
        headers.addAll(Map<String, String>.from(headersData));
      }
    }
    
    final queryParams = <String, String>{};
    
    // Parse query parameters
    if (action.properties.containsKey('query_params')) {
      final paramsData = action.properties['query_params'];
      if (paramsData is Map) {
        queryParams.addAll(Map<String, String>.from(paramsData));
      }
    }
    
    // Parse timeout
    int timeoutSeconds = 30; // 30 seconds default
    if (action.properties.containsKey('timeout')) {
      final timeoutValue = action.properties['timeout'];
      if (timeoutValue is int) {
        timeoutSeconds = timeoutValue;
      } else if (timeoutValue is String) {
        timeoutSeconds = int.tryParse(timeoutValue) ?? 30;
      }
    }
    
    // Parse expected status codes
    List<int> expectedCodes = [200, 201, 202, 204];
    if (action.properties.containsKey('expected_status_codes')) {
      final codesData = action.properties['expected_status_codes'];
      if (codesData is List) {
        expectedCodes = codesData.map((e) => int.tryParse(e.toString()) ?? 200).toList();
      }
    }
    
    return {
      'headers': headers,
      'queryParams': queryParams,
      'timeout': timeoutSeconds,
      'username': action.properties['username'],
      'password': action.properties['password'],
      'proxyHost': action.properties['proxy_host'],
      'proxyPort': int.tryParse(action.properties['proxy_port']?.toString() ?? '') ?? 8080,
      'proxyUsername': action.properties['proxy_username'],
      'proxyPassword': action.properties['proxy_password'],
      'followRedirects': action.properties['follow_redirects'] != 'false',
      'maxRedirects': int.tryParse(action.properties['max_redirects']?.toString() ?? '') ?? 5,
      'validateCertificate': action.properties['validate_certificate'] != 'false',
      'method': action.properties['method'] ?? 'GET',
      'requestBody': action.properties['request_body'],
      'contentType': action.properties['content_type'] ?? 'application/json',
      'expectSuccess': action.properties['expect_success'] != 'false',
      'expectedStatusCodes': expectedCodes,
      'expectedContentType': action.properties['expected_content_type'],
      'expectedText': action.properties['expected_text'],
    };
  }

  /// Execute basic connectivity test.
  Future<void> _executeConnectivity() async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    await socket.close();
    
    updateState({
      'connectivitySuccess': true,
      'operationOutput': 'Successfully connected to $host:$port',
    });
  }

  /// Execute HTTP request.
  Future<void> _executeHttp() async {
    final uri = _buildUri();
    final client = _createHttpClient();
    
    try {
      final request = await client.openUrl(method, uri);
      
      // Add headers
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      
      // Add authentication if provided
      if (username != null && password != null) {
        final credentials = base64Encode(utf8.encode('$username:$password'));
        request.headers.set('Authorization', 'Basic $credentials');
      }
      
      // Add request body if provided
      if (requestBody != null && (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
        request.headers.set('Content-Type', contentType);
        request.write(requestBody);
      }
      
      final startTime = DateTime.now();
      final response = await request.close();
      final endTime = DateTime.now();
      
      // Read response body
      final responseBodyBuffer = StringBuffer();
      await for (final chunk in response) {
        responseBodyBuffer.write(String.fromCharCodes(chunk));
      }
      
      final responseTime = endTime.difference(startTime);
      final responseBodyStr = responseBodyBuffer.toString();
      
      updateState({
        'responseCode': response.statusCode,
        'responseBody': responseBodyStr,
        'responseTime': responseTime.inMilliseconds,
        'operationOutput': 'HTTP ${response.statusCode} - ${response.reasonPhrase}',
      });
      
      // Validate response if expectations are set
      if (expectSuccess) {
        _validateResponse(response.statusCode, response.headers.contentType?.toString(), responseBodyStr);
      }
    } finally {
      client.close();
    }
  }

  /// Execute TCP connection test.
  Future<void> _executeTcp() async {
    final startTime = DateTime.now();
    final socket = await Socket.connect(host, port, timeout: timeout);
    final endTime = DateTime.now();
    
    await socket.close();
    
    final responseTime = endTime.difference(startTime);
    
    updateState({
      'connectivitySuccess': true,
      'responseTime': responseTime.inMilliseconds,
      'operationOutput': 'TCP connection successful to $host:$port',
    });
  }

  /// Execute UDP connection test.
  Future<void> _executeUdp() async {
    final startTime = DateTime.now();
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final endTime = DateTime.now();
    
    try {
      // Send a test packet
      final data = utf8.encode('test');
      final address = await InternetAddress.lookup(host).then((list) => list.first);
      socket.send(data, address, port);
      
      final responseTime = endTime.difference(startTime);
      
      updateState({
        'connectivitySuccess': true,
        'responseTime': responseTime.inMilliseconds,
        'operationOutput': 'UDP packet sent to $host:$port',
      });
    } finally {
      socket.close();
    }
  }

  /// Execute DNS resolution test.
  Future<void> _executeDns() async {
    final startTime = DateTime.now();
    final addresses = await InternetAddress.lookup(host);
    final endTime = DateTime.now();
    
    final responseTime = endTime.difference(startTime);
    final resolvedIP = addresses.isNotEmpty ? addresses.first.address : null;
    
    updateState({
      'dnsResolutionTime': responseTime.inMilliseconds,
      'resolvedIP': resolvedIP,
      'connectivitySuccess': addresses.isNotEmpty,
      'operationOutput': 'DNS resolved $host to ${addresses.map((a) => a.address).join(', ')}',
    });
  }

  /// Execute ping test.
  Future<void> _executePing() async {
    final result = await Process.run('ping', ['-c', '1', '-W', '5', host]);
    
    updateState({
      'connectivitySuccess': result.exitCode == 0,
      'operationOutput': result.stdout,
      'operationError': result.stderr,
    });
    
    if (result.exitCode != 0 && expectSuccess) {
      throw ActionFailedException('Ping failed: ${result.stderr}', moduleId: action.id);
    }
  }

  /// Execute port scan.
  Future<void> _executePortScan() async {
    final ports = action.properties['ports'] as String? ?? '22,80,443,8080';
    final portList = ports.split(',').map((p) => int.tryParse(p.trim()) ?? 0).where((p) => p > 0).toList();
    
    final results = <String, bool>{};
    
    for (final portNum in portList) {
      try {
        final socket = await Socket.connect(host, portNum, timeout: Duration(seconds: 5));
        await socket.close();
        results['$portNum'] = true;
      } catch (e) {
        results['$portNum'] = false;
      }
    }
    
    // final openPorts = results.entries.where((e) => e.value).map((e) => e.key).join(', ');
    
    updateState({
      'connectivitySuccess': results.values.any((open) => open),
      'operationOutput': 'Port scan results: ${results.toString()}',
    });
  }

  /// Build URI from configuration.
  Uri _buildUri() {
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    final uriString = '$protocol://$host:$port$path${queryString.isNotEmpty ? '?$queryString' : ''}';
    return Uri.parse(uriString);
  }

  /// Create HTTP client with proxy support.
  HttpClient _createHttpClient() {
    final client = HttpClient();
    
    // Configure timeout
    client.connectionTimeout = timeout;
    
    // Configure proxy if provided
    if (proxyHost != null) {
      client.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort';
      
      if (proxyUsername != null && proxyPassword != null) {
      client.authenticate = (url, scheme, realm) async {
        return url.host == proxyHost && url.port == proxyPort;
      };
      }
    }
    
    // Configure SSL certificate validation
    if (!validateCertificate) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    
    return client;
  }

  /// Validate HTTP response.
  void _validateResponse(int statusCode, String? contentType, String body) {
    if (!expectedStatusCodes.contains(statusCode)) {
      throw ActionFailedException(
        'Expected status codes ${expectedStatusCodes.join(', ')}, but got $statusCode',
        moduleId: action.id,
      );
    }
    
    if (expectedContentType != null && !contentType!.contains(expectedContentType!)) {
      throw ActionFailedException(
        'Expected content type to contain "$expectedContentType", but got "$contentType"',
        moduleId: action.id,
      );
    }
    
    if (expectedText != null && !body.contains(expectedText!)) {
      throw ActionFailedException(
        'Expected response body to contain "$expectedText", but it was not found',
        moduleId: action.id,
      );
    }
  }
}
