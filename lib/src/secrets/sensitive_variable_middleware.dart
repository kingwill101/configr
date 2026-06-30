import 'package:i3config/i3config_v2.dart' as i3;

import '../secrets/secret_provider.dart' show SensitiveValue;

/// A [i3.VariableMiddleware] that tracks sensitive variable names and values
/// for redaction in logs, dry-run output, and event messages.
///
/// This replaces the earlier ad-hoc `context.options['_sensitiveKeys']` /
/// `context.options['_sensitiveValues']` pattern with a first-class middleware
/// that integrates with the i3config middleware chain at both the processor
/// and context level.
///
/// # Lifecycle
///
/// 1. Register at the processor level in `v2_apply.dart` so it propagates to
///    all contexts automatically.
/// 2. Blocks such as `secrets_block.dart` call [markSensitive] to register
///    sensitive key names after resolving secret URIs.
/// 3. On variable access, [onSet] intercepts `SensitiveValue` markers and
///    registers them automatically. [onGet] and [onExpand] pass through
///    unchanged — the actual values are needed for processing.
/// 4. Output-producing code (e.g. `action_block.dart` dry-run / event
///    redaction) calls [redact] which replaces known sensitive values with
///    `<REDACTED>`.
///
/// # Why pass-through on onGet / onExpand?
///
/// Unlike a generic secret-storage middleware, this middleware is designed for
/// **redaction of actual secret values in output channels** rather than
/// controlling variable access. The values must remain available for blocks
/// that use them (templates, environment variables, etc.). Redaction happens
/// at the presentation layer.
class SensitiveVariableMiddleware implements i3.VariableMiddleware {
  final Set<String> _names = {};
  final Map<String, String> _values = {};

  /// The set of sensitive variable names.
  Set<String> get sensitiveKeys => Set.unmodifiable(_names);

  /// The map of sensitive variable names to their actual values.
  Map<String, String> get sensitiveValues => Map.unmodifiable(_values);

  /// Whether any sensitive variables have been registered.
  bool get hasSensitiveKeys => _names.isNotEmpty;

  /// Register a variable name and its actual value as sensitive.
  void markSensitive(String name, String value) {
    _names.add(name);
    _values[name] = value;
  }

  /// Redact known sensitive values from [message].
  ///
  /// Replaces each registered sensitive value (when 4+ characters) with
  /// `<REDACTED>` in the given text. This is used for dry-run summaries,
  /// event messages, and log output.
  String redact(String message) {
    var result = message;
    for (final value in _values.values) {
      if (value.length < 4) continue;
      result = result.replaceAll(value, '<REDACTED>');
    }
    return result;
  }

  @override
  dynamic onSet(String name, dynamic value, i3.Context context) {
    if (value is SensitiveValue) {
      markSensitive(name, value.value);
      return value.value;
    }
    return value;
  }

  @override
  dynamic onGet(String name, dynamic value, i3.Context context) => value;

  @override
  String? onExpand(String text, i3.Context context) => text;
}
