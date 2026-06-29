import 'package:configr/src/secrets/sensitive_variable_middleware.dart'
    show SensitiveVariableMiddleware;
import 'package:configr/src/secrets/secret_provider.dart' show SensitiveValue;
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:test/test.dart';

void main() {
  group('SensitiveVariableMiddleware', () {
    late SensitiveVariableMiddleware mw;

    setUp(() {
      mw = SensitiveVariableMiddleware();
    });

    test('has no sensitive keys initially', () {
      expect(mw.hasSensitiveKeys, isFalse);
      expect(mw.sensitiveKeys, isEmpty);
      expect(mw.sensitiveValues, isEmpty);
    });

    test('markSensitive registers key and value', () {
      mw.markSensitive('db_password', 'supersecret123');
      expect(mw.hasSensitiveKeys, isTrue);
      expect(mw.sensitiveKeys, contains('db_password'));
      expect(mw.sensitiveValues['db_password'], equals('supersecret123'));
    });

    test('markSensitive is additive', () {
      mw.markSensitive('a', '1');
      mw.markSensitive('b', '2');
      expect(mw.sensitiveKeys, hasLength(2));
      expect(mw.sensitiveValues['a'], equals('1'));
      expect(mw.sensitiveValues['b'], equals('2'));
    });

    test('redact replaces long values with <REDACTED>', () {
      mw.markSensitive('secret', 'mysecretpassword');
      expect(mw.redact('mysecretpassword'), equals('<REDACTED>'));
      expect(
        mw.redact('prefix mysecretpassword suffix'),
        equals('prefix <REDACTED> suffix'),
      );
    });

    test('redact skips short values (length < 4)', () {
      mw.markSensitive('short', 'ab');
      expect(mw.redact('ab ab'), equals('ab ab'));
      expect(mw.redact('abc abc'), equals('abc abc'));
      expect(mw.redact('abcd'), equals('abcd')); // length == 4, < not <=
    });

    test('redact handles multiple sensitive values', () {
      mw.markSensitive('pw1', 'secret1');
      mw.markSensitive('pw2', 'secret2');
      expect(
        mw.redact('secret1 and secret2'),
        equals('<REDACTED> and <REDACTED>'),
      );
    });

    test('redact returns unchanged text when no sensitive keys', () {
      expect(mw.redact('some text'), equals('some text'));
    });

    test('onSet auto-registers SensitiveValue wrapper', () {
      final ctx = i3.Context();
      final result = mw.onSet('api_key', SensitiveValue('tok12345'), ctx);
      expect(result, 'tok12345');
      expect(mw.sensitiveKeys, contains('api_key'));
      expect(mw.sensitiveValues['api_key'], equals('tok12345'));
    });

    test('onSet passes through plain strings unchanged', () {
      final ctx = i3.Context();
      final result = mw.onSet('name', 'Alice', ctx);
      expect(result, 'Alice');
      expect(mw.hasSensitiveKeys, isFalse);
    });

    test('onGet passes through values unchanged', () {
      final ctx = i3.Context();
      expect(mw.onGet('key', 'value', ctx), 'value');
      expect(mw.onGet('key', 42, ctx), 42);
      expect(mw.onGet('key', null, ctx), isNull);
    });

    test('onExpand passes through text unchanged', () {
      final ctx = i3.Context();
      expect(mw.onExpand('hello \$world', ctx), 'hello \$world');
      expect(mw.onExpand('', ctx), '');
    });

    test('redact with overlapping values uses longest match first', () {
      mw.markSensitive('a', 'abc');
      mw.markSensitive('b', 'abcd');
      expect(mw.redact('xabcdy'), equals('x<REDACTED>y'));
    });
  });
}
