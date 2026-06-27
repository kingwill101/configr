abstract class SecretProvider {
  const SecretProvider();
  Future<String?> get(String project, String key, String? profile);
}

abstract class Sensitive {
  bool get isSensitive;
}

class SensitiveValue implements Sensitive {
  final String _value;

  const SensitiveValue(this._value);

  String get value => _value;

  @override
  bool get isSensitive => true;

  @override
  String toString() => '<SENSITIVE>';

  @override
  int get hashCode => _value.hashCode;

  @override
  bool operator ==(Object other) =>
      other is SensitiveValue && other._value == _value;
}

String displayValue(dynamic value) {
  if (value is SensitiveValue) return '<SENSITIVE>';
  return value?.toString() ?? '<null>';
}
