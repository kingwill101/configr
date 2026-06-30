import 'dart:convert';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/network_service.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Block handler for the `network` config action.
///
/// Performs network connectivity checks: HTTP, TCP, DNS, and ping.
///
/// ```i3
/// network {
///   source = "https://example.com/health"
///   operation = "http"             # http | tcp | dns | ping | connectivity
///   port = 443
///   timeout = 30
///   expected_status = 200
///   expected_text = "OK"
/// }
/// ```
class NetworkBlock extends ActionBlock {
  @override
  String get blockType => 'network';

  // ---------------------------------------------------------------------------
  // Network-specific properties
  // ---------------------------------------------------------------------------

  String? host;
  String operation = 'connectivity';
  int port = 80;
  int timeout = 30;
  int? expectedStatus;
  String? expectedText;
  String? expectedContentType;
  String method = 'GET';
  String? requestBody;
  String? contentType;
  String? username;
  String? password;
  bool followRedirects = true;
  bool validateCertificate = true;

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  bool connectivitySuccess = false;
  int? responseCode;
  String? responseBody;
  int responseTimeMs = 0;
  String? resolvedIP;
  int dnsResolutionTimeMs = 0;

  NetworkBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (operation != 'connectivity') 'operation': operation,
    'host': ?host,
    if (port != 80) 'port': port.toString(),
    if (timeout != 30) 'timeout': timeout.toString(),
    if (expectedStatus != null) 'expected_status': expectedStatus.toString(),
    'expected_text': ?expectedText,
    'expected_content_type': ?expectedContentType,
    if (method != 'GET') 'method': method,
    'request_body': ?requestBody,
    'content_type': ?contentType,
    'username': ?username,
    'password': ?password,
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (!followRedirects) 'follow_redirects': followRedirects,
    if (!validateCertificate) 'validate_certificate': validateCertificate,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    host = source.isNotEmpty ? source : null;
    operation = (context.getVariable('operation') as String?) ?? 'connectivity';

    final p = context.getVariable('port');
    if (p is int) port = p;
    if (p is String) port = int.tryParse(p) ?? 80;

    final t = context.getVariable('timeout');
    if (t is int) timeout = t;
    if (t is String) timeout = int.tryParse(t) ?? 30;

    final es = context.getVariable('expected_status');
    if (es is int) expectedStatus = es;
    if (es is String) expectedStatus = int.tryParse(es);

    expectedText = context.getVariable('expected_text') as String?;
    expectedContentType =
        context.getVariable('expected_content_type') as String?;
    method = (context.getVariable('method') as String?) ?? 'GET';
    requestBody = context.getVariable('request_body') as String?;
    contentType = context.getVariable('content_type') as String?;
    username = context.getVariable('username') as String?;
    password = context.getVariable('password') as String?;

    followRedirects = switch (context.getVariable('follow_redirects')) {
      false || 'false' => false,
      _ => true,
    };

    validateCertificate = switch (context.getVariable('validate_certificate')) {
      false || 'false' => false,
      _ => true,
    };
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting network $operation to $source',
      ),
    );

    try {
      switch (operation.toLowerCase()) {
        case 'connectivity':
          await _executeConnectivity();
          break;
        case 'http':
          await _executeHttp();
          break;
        case 'tcp':
          await _executeTcp();
          break;
        case 'dns':
          await _executeDns();
          break;
        case 'ping':
          await _executePing();
          break;
        default:
          throw ActionFailedException(
            'Unknown network operation: $operation',
            moduleId: id,
          );
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Network $operation to $source completed',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(moduleId: id, message: 'Network $operation failed: $e'),
      );
      throw ActionFailedException(
        'Network $operation to $source failed',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    // Network operations are read-only, no rollback needed
    for (final child in children) {
      await child.rollback();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _executeConnectivity() async {
    final result = await networkService.probeConnectivity(
      source,
      timeoutSeconds: timeout,
    );
    connectivitySuccess = result.success;
    resolvedIP = result.resolvedAddress;
    dnsResolutionTimeMs = result.elapsedMs;
  }

  Future<void> _executeHttp() async {
    final headers = <String, String>{};
    if (contentType != null) {
      headers['Content-Type'] = contentType!;
    }
    if (username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $credentials';
    }

    final result = await networkService.probeHttp(
      NetworkRequest(
        method: method,
        uri: Uri.parse(source),
        headers: headers,
        body: requestBody ?? '',
        timeoutSeconds: timeout,
        validateCertificates: validateCertificate,
      ),
    );
    responseCode = result.statusCode;
    responseBody = result.body;
    responseTimeMs = result.elapsedMs;

    if (expectedStatus != null && responseCode != expectedStatus) {
      throw ActionFailedException(
        'Expected status $expectedStatus, got $responseCode',
        moduleId: id,
      );
    }

    if (expectedText != null && !responseBody!.contains(expectedText!)) {
      throw ActionFailedException(
        'Response body does not contain expected text: "$expectedText"',
        moduleId: id,
      );
    }

    if (expectedContentType != null) {
      final ct = result.headers['content-type'] ?? '';
      if (!ct.contains(expectedContentType!)) {
        throw ActionFailedException(
          'Expected content-type "$expectedContentType", got "$ct"',
          moduleId: id,
        );
      }
    }
  }

  Future<void> _executeTcp() async {
    final result = await networkService.probeTcp(
      source,
      port,
      timeoutSeconds: timeout,
    );
    responseTimeMs = result.elapsedMs;
    connectivitySuccess = result.success;
  }

  Future<void> _executeDns() async {
    final result = await networkService.probeDns(
      source,
      timeoutSeconds: timeout,
    );
    resolvedIP = result.resolvedAddress;
    dnsResolutionTimeMs = result.elapsedMs;
    connectivitySuccess = result.success;
  }

  Future<void> _executePing() async {
    final result = await networkService.probePing(
      source,
      timeoutSeconds: timeout,
    );
    responseTimeMs = result.elapsedMs;
    connectivitySuccess = result.success;
  }
}
