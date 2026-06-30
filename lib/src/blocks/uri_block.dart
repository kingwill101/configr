import 'dart:async';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/network_service.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class UriBlock extends ActionBlock {
  @override
  String get blockType => 'uri';

  String url = '';
  String method = 'GET';
  Map<String, String> headers = {};
  String body = '';
  int statusCode = 200;
  int timeout = 30;
  bool validateCerts = true;

  UriBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (url.isNotEmpty) 'url': url,
    if (method != 'GET') 'method': method,
    if (body.isNotEmpty) 'body': body,
    if (statusCode != 200) 'status_code': statusCode.toString(),
    if (timeout != 30) 'timeout': timeout.toString(),
    if (!validateCerts) 'validate_certs': 'false',
  };

  @override
  void resetState() {
    super.resetState();
    url = '';
    method = 'GET';
    headers = {};
    body = '';
    statusCode = 200;
    timeout = 30;
    validateCerts = true;
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    url = (context.getVariable('url') as String?) ?? '';
    method = (context.getVariable('method') as String?) ?? 'GET';
    final rawHeaders = context.getVariable('headers');
    if (rawHeaders is Map) {
      headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    body = (context.getVariable('body') as String?) ?? '';
    statusCode = switch (context.getVariable('status_code')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 200,
      _ => 200,
    };
    timeout = switch (context.getVariable('timeout')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 30,
      _ => 30,
    };
    validateCerts = switch (context.getVariable('validate_certs')) {
      false || 'false' => false,
      _ => true,
    };
  }

  @override
  String dryRunSummary() {
    if (url.isEmpty) return '$blockType: (empty)';
    return '$blockType: $method $url';
  }

  @override
  Future<void> execute() async {
    if (url.isEmpty) {
      throw ActionFailedException('url is required for uri', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: '$method $url'));

    try {
      final response = await networkService.request(
        NetworkRequest(
          method: method,
          uri: Uri.parse(url),
          headers: headers,
          body: body,
          timeoutSeconds: timeout,
          validateCertificates: validateCerts,
        ),
      );

      if (response.statusCode != statusCode) {
        throw ActionFailedException(
          'Expected status $statusCode but got ${response.statusCode}: '
          '${response.body}',
          moduleId: id,
        );
      }

      context.setVariable('uri_status', response.statusCode);
      context.setVariable('uri_content', response.body);
      context.setVariable('uri_method', method);
      context.setVariable('uri_url', url);

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: '$method $url returned ${response.statusCode}',
        ),
      );
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      if (e is TimeoutException) {
        throw ActionFailedException(
          'Request timed out after ${timeout}s: $url',
          moduleId: id,
        );
      }
      throw ActionFailedException('uri failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}
