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

  test('should return empty map for unknown host', () async {
    final facts = await hostVars.factsFor('unknown');
    expect(facts, isEmpty);
  });

  test('should return facts for a known host', () async {
    await fs.file('.configr/facts/web-01.json').create(recursive: true);
    await fs
        .file('.configr/facts/web-01.json')
        .writeAsString('{"os_family": "debian", "hostname": "web-01"}');

    final facts = await hostVars.factsFor('web-01');
    expect(facts, containsPair('os_family', 'debian'));
    expect(facts, containsPair('hostname', 'web-01'));
  });

  test('should return empty map for malformed fact file', () async {
    await fs.file('.configr/facts/bad.json').create(recursive: true);
    await fs.file('.configr/facts/bad.json').writeAsString('not json');

    final facts = await hostVars.factsFor('bad');
    expect(facts, isEmpty);
  });

  test('should return all facts for all hosts', () async {
    await fs.file('.configr/facts/web-01.json').create(recursive: true);
    await fs
        .file('.configr/facts/web-01.json')
        .writeAsString('{"os_family": "debian"}');
    await fs.file('.configr/facts/db-01.json').create(recursive: true);
    await fs
        .file('.configr/facts/db-01.json')
        .writeAsString('{"os_family": "ubuntu"}');

    final all = await hostVars.allFacts();
    expect(all, hasLength(2));
    expect(all['web-01'], containsPair('os_family', 'debian'));
    expect(all['db-01'], containsPair('os_family', 'ubuntu'));
  });

  test('should return empty allFacts when facts dir missing', () async {
    final all = await hostVars.allFacts();
    expect(all, isEmpty);
  });

  test('hasFacts should return true when fact file exists', () async {
    await fs.file('.configr/facts/web-01.json').create(recursive: true);
    await fs.file('.configr/facts/web-01.json').writeAsString('{}');

    expect(await hostVars.hasFacts('web-01'), isTrue);
    expect(await hostVars.hasFacts('unknown'), isFalse);
  });

  test('should return specific fact for a host', () async {
    await fs.file('.configr/facts/web-01.json').create(recursive: true);
    await fs
        .file('.configr/facts/web-01.json')
        .writeAsString('{"os_family": "debian", "processor_count": "4"}');

    expect(await hostVars.factFor('web-01', 'os_family'), equals('debian'));
    expect(await hostVars.factFor('web-01', 'processor_count'), equals('4'));
    expect(await hostVars.factFor('web-01', 'nonexistent'), isNull);
    expect(await hostVars.factFor('unknown', 'anything'), isNull);
  });

  test('should skip non-json files in allFacts', () async {
    await fs.file('.configr/facts/readme.txt').create(recursive: true);
    await fs.file('.configr/facts/readme.txt').writeAsString('hello');
    await fs.file('.configr/facts/web-01.json').create(recursive: true);
    await fs
        .file('.configr/facts/web-01.json')
        .writeAsString('{"os_family": "debian"}');

    final all = await hostVars.allFacts();
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
