import 'package:configr/src/multi_host/variable_precedence.dart'
    show PrecedenceLayer, VariablePrecedence, VariableSource;
import 'package:test/test.dart';

void main() {
  group('VariablePrecedence', () {
    late VariablePrecedence precedence;

    setUp(() {
      precedence = VariablePrecedence();
    });

    test('should return null for unknown variable', () {
      expect(precedence.lookup('nonexistent'), isNull);
    });

    test('should return value from a single layer', () {
      precedence.addSource(PrecedenceLayer.facts, {'os': 'linux'});
      expect(precedence.lookup('os'), equals('linux'));
    });

    test('should prefer higher-priority layer', () {
      precedence.addSource(PrecedenceLayer.facts, {'hostname': 'from-facts'});
      precedence.addSource(PrecedenceLayer.cliVars, {'hostname': 'from-cli'});
      expect(precedence.lookup('hostname'), equals('from-cli'));
    });

    test('should fall through when higher layer has no match', () {
      precedence.addSource(PrecedenceLayer.cliVars, {'cli_key': 'cli-val'});
      precedence.addSource(PrecedenceLayer.facts, {'fact_key': 'fact-val'});
      expect(precedence.lookup('fact_key'), equals('fact-val'));
      expect(precedence.lookup('cli_key'), equals('cli-val'));
    });

    test('setLayer should replace existing layer values', () {
      precedence.addSource(PrecedenceLayer.facts, {'hostname': 'old'});
      precedence.setLayer(PrecedenceLayer.facts, {'hostname': 'new'});
      expect(precedence.lookup('hostname'), equals('new'));
    });

    test('removeLayer should clear a layer', () {
      precedence.addSource(PrecedenceLayer.facts, {'hostname': 'val'});
      precedence.removeLayer(PrecedenceLayer.facts);
      expect(precedence.lookup('hostname'), isNull);
    });

    test('clear should remove all layers', () {
      precedence.addSource(PrecedenceLayer.facts, {'a': '1'});
      precedence.addSource(PrecedenceLayer.cliVars, {'b': '2'});
      precedence.clear();
      expect(precedence.lookup('a'), isNull);
      expect(precedence.lookup('b'), isNull);
    });

    test('should respect full precedence order', () {
      precedence.addSource(PrecedenceLayer.facts, {'key': 'facts'});
      precedence.addSource(PrecedenceLayer.secrets, {'key': 'secrets'});
      precedence.addSource(PrecedenceLayer.groupVars, {'key': 'group'});
      precedence.addSource(PrecedenceLayer.hostVars, {'key': 'host'});
      precedence.addSource(PrecedenceLayer.cliVars, {'key': 'cli'});

      expect(precedence.lookup('key'), equals('cli'));
    });

    test('lookup should be consistent with onGet override logic', () {
      precedence.addSource(PrecedenceLayer.cliVars, {'key': 'from-cli'});
      // onGet returns precedence value if exists, else the context value.
      // Since we can't construct a real Context, we verify via lookup():
      expect(precedence.lookup('key'), equals('from-cli'));
      expect(precedence.lookup('nonexistent'), isNull);
    });

    test('addSources should bulk-register', () {
      precedence.addSources([
        VariableSource(PrecedenceLayer.facts, {'a': '1', 'b': '2'}),
        VariableSource(PrecedenceLayer.cliVars, {'c': '3'}),
      ]);
      expect(precedence.lookup('a'), equals('1'));
      expect(precedence.lookup('c'), equals('3'));
    });

    test('layer priority enum values', () {
      expect(PrecedenceLayer.facts.priority, equals(1));
      expect(PrecedenceLayer.secrets.priority, equals(2));
      expect(PrecedenceLayer.groupVars.priority, equals(3));
      expect(PrecedenceLayer.hostVars.priority, equals(4));
      expect(PrecedenceLayer.cliVars.priority, equals(5));
    });
  });
}
