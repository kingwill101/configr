import 'package:test/test.dart';
import 'v2_test_helper.dart';

void main() {
  late V2TestHelper helper;

  setUp(() {
    helper = V2TestHelper();
  });

  group('container block', () {
    test('should parse image and name', () async {
      final blocks = await helper.processConfig('''
        container {
          image = "nginx"
          container_name = "web-proxy"
        }
      ''');

      expect(blocks, hasLength(1));
      final block = blocks.first;
      expect(block.blockType, equals('container'));
      expect((block as dynamic).image, equals('nginx'));
      expect((block as dynamic).containerName, equals('web-proxy'));
    });

    test('should parse all properties', () async {
      final blocks = await helper.processConfig('''
        container {
          image = "nginx"
          tag = "1.25"
          container_name = "web"
          state = "running"
          ports = "80:80,443:443"
          volumes = "/data:/data"
          env = "NGINX_HOST=localhost"
          restart_policy = "always"
          network = "host"
          pull = true
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.image, equals('nginx'));
      expect(block.tag, equals('1.25'));
      expect(block.containerName, equals('web'));
      expect(block.state, equals('running'));
      expect(block.ports, equals('80:80,443:443'));
      expect(block.volumes, equals('/data:/data'));
      expect(block.env, equals('NGINX_HOST=localhost'));
      expect(block.restartPolicy, equals('always'));
      expect(block.network, equals('host'));
      expect(block.pull, isTrue);
    });

    test('should use defaults for optional properties', () async {
      final blocks = await helper.processConfig('''
        container {
          image = "redis"
          container_name = "cache"
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.image, equals('redis'));
      expect(block.tag, equals('latest'));
      expect(block.state, equals('running'));
      expect(block.pull, isFalse);
      expect(block.ports, isEmpty);
    });

    test('should parse state as absent', () async {
      final blocks = await helper.processConfig('''
        container {
          image = "nginx"
          container_name = "web"
          state = "absent"
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.state, equals('absent'));
    });

    test('should parse health_check', () async {
      final blocks = await helper.processConfig('''
        container {
          image = "nginx"
          container_name = "web"
          health_check = "curl -f http://localhost"
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.healthCheck, equals('curl -f http://localhost'));
    });
  });

  group('container_exec block', () {
    test('should parse container and command', () async {
      final blocks = await helper.processConfig('''
        container_exec {
          container = "web"
          command = "nginx -s reload"
        }
      ''');

      expect(blocks, hasLength(1));
      final block = blocks.first;
      expect(block.blockType, equals('container_exec'));
      expect((block as dynamic).containerName, equals('web'));
      expect((block as dynamic).command, equals('nginx -s reload'));
    });

    test('should parse working_dir', () async {
      final blocks = await helper.processConfig('''
        container_exec {
          container = "web"
          command = "ls -la"
          working_dir = "/app"
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.workingDir, equals('/app'));
    });

    test('should parse interactive flag', () async {
      final blocks = await helper.processConfig('''
        container_exec {
          container = "web"
          command = "bash"
          interactive = true
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.interactive, isTrue);
    });
  });

  group('container_logs block', () {
    test('should parse container name', () async {
      final blocks = await helper.processConfig('''
        container_logs {
          container = "web"
        }
      ''');

      expect(blocks, hasLength(1));
      final block = blocks.first;
      expect(block.blockType, equals('container_logs'));
      expect((block as dynamic).containerName, equals('web'));
    });

    test('should parse tail count', () async {
      final blocks = await helper.processConfig('''
        container_logs {
          container = "web"
          tail = 50
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.tail, equals(50));
    });

    test('should parse timestamps flag', () async {
      final blocks = await helper.processConfig('''
        container_logs {
          container = "web"
          timestamps = true
        }
      ''');

      final block = blocks.first as dynamic;
      expect(block.timestamps, isTrue);
    });
  });
}
