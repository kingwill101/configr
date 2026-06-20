import 'package:configr/exceptions.dart';
import 'package:configr/models/action.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/modules/resource/network.dart';
import 'package:test/test.dart';

void main() {
  group('FileNetworkModule', () {
    late FileNetworkModule networkModule;
    late Action action;
    late ResourceModel file;

    setUp(() {
      action = Action(
        id: 'test-network-action',
        type: 'network',
        properties: {},
      );
      file = ResourceModel(
        id: 'test-file',
        source: 'http://example.com',
        destination: 'http://example.com',
        type: 'network',
        actions: [action],
      );
      networkModule = FileNetworkModule(file, action);
    });

    group('Initialization', () {
      test('should initialize with default values', () {
        expect(networkModule.host, isEmpty);
        expect(networkModule.port, equals(80));
        expect(networkModule.protocol, equals('http'));
        expect(networkModule.path, equals('/'));
        expect(networkModule.connectivitySuccess, isFalse);
        expect(networkModule.responseCode, equals(-1));
        expect(networkModule.responseBody, isNull);
        expect(networkModule.responseTime.inMilliseconds, equals(0));
        expect(networkModule.timeout.inSeconds, equals(30));
        expect(networkModule.headers, isEmpty);
        expect(networkModule.username, isNull);
        expect(networkModule.password, isNull);
        expect(networkModule.proxyHost, isNull);
        expect(networkModule.proxyPort, equals(8080));
        expect(networkModule.followRedirects, isTrue);
        expect(networkModule.maxRedirects, equals(5));
        expect(networkModule.validateCertificate, isTrue);
        expect(networkModule.method, equals('GET'));
        expect(networkModule.contentType, equals('application/json'));
        expect(networkModule.queryParams, isEmpty);
        expect(networkModule.requestBody, isNull);
        expect(networkModule.expectedStatusCodes, equals([200, 201, 202, 204]));
        expect(networkModule.expectedContentType, isNull);
        expect(networkModule.expectedText, isNull);
        expect(networkModule.connectivitySuccess, isFalse);
        expect(networkModule.operationDuration.inMilliseconds, equals(0));
        expect(networkModule.operationOutput, isNull);
        expect(networkModule.operationError, isNull);
      });

      test('should update state with configuration', () {
        final config = {
          'host': 'example.com',
          'port': '443',
          'timeout': '30',
          'method': 'GET',
          'headers': {'Authorization': 'Bearer token123'},
          'query_params': {'page': '1'},
          'proxy_host': 'proxy.example.com',
          'proxy_port': '8080',
          'max_redirects': '5',
          'expected_status_codes': [200, 201, 202, 204],
          'validate_certificate': 'true',
          'follow_redirects': 'true',
          'username': 'testuser',
          'password': 'testpass',
          'request_body': '{"test": "data"}',
          'content_type': 'application/json',
        };

        action.properties = config;
        networkModule = FileNetworkModule(file, action);
        
        // Manually update state to simulate what happens in execute()
        networkModule.updateState({
          'host': 'example.com',
          'port': 443,
          'timeout': 30,
          'method': 'GET',
          'headers': {'Authorization': 'Bearer token123'},
          'queryParams': {'page': '1'},
          'proxyHost': 'proxy.example.com',
          'proxyPort': 8080,
          'maxRedirects': 5,
          'expectedStatusCodes': [200, 201, 202, 204],
          'validateCertificate': true,
          'followRedirects': true,
          'username': 'testuser',
          'password': 'testpass',
          'requestBody': '{"test": "data"}',
          'contentType': 'application/json',
        });

        expect(networkModule.host, equals('example.com'));
        expect(networkModule.port, equals(443));
        expect(networkModule.timeout.inSeconds, equals(30));
        expect(networkModule.method, equals('GET'));
        expect(networkModule.headers['Authorization'], equals('Bearer token123'));
        expect(networkModule.queryParams['page'], equals('1'));
        expect(networkModule.proxyHost, equals('proxy.example.com'));
        expect(networkModule.proxyPort, equals(8080));
        expect(networkModule.maxRedirects, equals(5));
        expect(networkModule.expectedStatusCodes, equals([200, 201, 202, 204]));
        expect(networkModule.validateCertificate, isTrue);
        expect(networkModule.followRedirects, isTrue);
        expect(networkModule.username, equals('testuser'));
        expect(networkModule.password, equals('testpass'));
        expect(networkModule.requestBody, equals('{"test": "data"}'));
        expect(networkModule.contentType, equals('application/json'));
      });
    });

    group('Operation Validation', () {
      test('should validate unknown operation', () async {
        action.properties = {
          'operation': 'unknown',
          'host': 'example.com',
        };

        networkModule = FileNetworkModule(file, action);
        
        expect(
          () => networkModule.execute(),
          throwsA(isA<ActionFailedException>().having(
            (e) => e.toString(),
            'message',
            contains('Unknown network operation: unknown'),
          )),
        );
      });
    });

    group('State Management', () {
      test('should update state correctly', () {
        networkModule.updateState({
          'host': 'example.com',
          'connectivitySuccess': true,
          'responseCode': 200,
        });

        expect(networkModule.host, equals('example.com'));
        expect(networkModule.connectivitySuccess, isTrue);
        expect(networkModule.responseCode, equals(200));
      });

      test('should preserve existing state when updating', () {
        networkModule.updateState({'host': 'example.com'});
        networkModule.updateState({'connectivitySuccess': true});

        expect(networkModule.host, equals('example.com'));
        expect(networkModule.connectivitySuccess, isTrue);
      });
    });

    group('Operation Duration', () {
      test('should track operation duration', () {
        networkModule.updateState({'operationDuration': 1500});
        expect(networkModule.operationDuration.inMilliseconds, equals(1500));
      });

      test('should default operation duration to zero', () {
        expect(networkModule.operationDuration.inMilliseconds, equals(0));
      });
    });

    group('Operation Output', () {
      test('should track operation output', () {
        networkModule.updateState({'operationOutput': 'Network operation successful'});
        expect(networkModule.operationOutput, equals('Network operation successful'));
      });

      test('should track operation error', () {
        networkModule.updateState({'operationError': 'Network operation failed'});
        expect(networkModule.operationError, equals('Network operation failed'));
      });
    });

    group('Rollback', () {
      test('should handle rollback gracefully', () async {
        action.properties = {
          'operation': 'ping',
          'host': 'example.com',
        };

        networkModule = FileNetworkModule(file, action);

        // Should not throw exception
        expect(() => networkModule.rollback(), returnsNormally);
      });
    });
  });
}