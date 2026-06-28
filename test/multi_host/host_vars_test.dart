import 'package:configr/src/multi_host/host_vars.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late HostVars hostVars;

  setUp(() {
    fs = MemoryFileSystem();
    hostVars = HostVars(factsDir: '.configr/facts', fs: fs);
  });

  test('should return empty map for unknown host', () {
    final facts = hostVars.factsFor('unknown');
    expect(facts, isEmpty);
  });

  test('should return facts for a known host', () {
    fs.file('.configr/facts/web-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"os_family": "debian", "hostname": "web-01"}');

    final facts = hostVars.factsFor('web-01');
    expect(facts, containsPair('os_family', 'debian'));
    expect(facts, containsPair('hostname', 'web-01'));
  });

  test('should return empty map for malformed fact file', () {
    fs.file('.configr/facts/bad.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('not json');

    final facts = hostVars.factsFor('bad');
    expect(facts, isEmpty);
  });

  test('should return all facts for all hosts', () {
    fs.file('.configr/facts/web-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"os_family": "debian"}');
    fs.file('.configr/facts/db-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"os_family": "ubuntu"}');

    final all = hostVars.allFacts();
    expect(all, hasLength(2));
    expect(all['web-01'], containsPair('os_family', 'debian'));
    expect(all['db-01'], containsPair('os_family', 'ubuntu'));
  });

  test('should return empty allFacts when facts dir missing', () {
    final all = hostVars.allFacts();
    expect(all, isEmpty);
  });

  test('hasFacts should return true when fact file exists', () {
    fs.file('.configr/facts/web-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');

    expect(hostVars.hasFacts('web-01'), isTrue);
    expect(hostVars.hasFacts('unknown'), isFalse);
  });

  test('should return specific fact for a host', () {
    fs.file('.configr/facts/web-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"os_family": "debian", "processor_count": "4"}');

    expect(hostVars.factFor('web-01', 'os_family'), equals('debian'));
    expect(hostVars.factFor('web-01', 'processor_count'), equals('4'));
    expect(hostVars.factFor('web-01', 'nonexistent'), isNull);
    expect(hostVars.factFor('unknown', 'anything'), isNull);
  });

  test('should skip non-json files in allFacts', () {
    fs.file('.configr/facts/readme.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('hello');
    fs.file('.configr/facts/web-01.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"os_family": "debian"}');

    final all = hostVars.allFacts();
    expect(all, hasLength(1));
    expect(all, containsPair('web-01', {'os_family': 'debian'}));
  });

  test('registerInContext should add hostvars entry', () {
    final context = <String, dynamic>{};
    hostVars.registerInContext(context);

    expect(context, containsPair('hostvars', <String, Map<String, dynamic>>{}));
    expect(context, containsPair('_hostVarsService', isNotNull));
    expect(context['_hostVarsService'], same(hostVars));
  });
}
