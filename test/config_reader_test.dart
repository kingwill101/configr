import 'package:configr/utils/config_reader.dart';
import 'package:test/test.dart';

void main() {
  group('Config Reader Tests', () {
    late String configString;

    setUp(() {
      configString = '''
resources {
  resource {
    source = "i3/config"
    destination = "~/.config/i3/config"
    actions {
      copy {
        status = "completed"
        timestamp = "2024-08-21T12:34:56Z"
      }
      executable {
        status = "completed"
        timestamp = "2024-08-21T12:34:57Z"
      }
    }
  }
  resource {
    source = "dunst/dunstrc"
    destination = "~/.config/dunst/dunstrc"
    actions {
      copy {
        status = "completed"
        timestamp = "2024-08-21T12:35:10Z"
      }
    }
  }
}
commands {
  command install-dependencies {
    status = "completed"
    timestamp = "2024-08-21T12:36:00Z"
    parameters = "i3 dunst alacritty"
  }
  command update-packages {
    status = "completed"
    timestamp = "2024-08-21T12:36:05Z"
  }
}
packages {
  package {
    name = "i3"
    manager = "apt"
    version = "4.18.2-1"
    scope = "global"
    status = "installed"
    timestamp = "2024-08-21T12:36:10Z"
  }
  package {
    name = "dunst"
    manager = "pip"
    version = "1.5.0"
    scope = "config"
    status = "installed"
    timestamp = "2024-08-21T12:36:20Z"
  }
}
''';
    });

    test('parseConfig should correctly parse resources section', () {
      final result = parseConfig(configString);

      expect(result.resources, hasLength(2));
      expect(result.resources[0].source, equals("i3/config"));
      expect(result.resources[0].destination, equals("~/.config/i3/config"));
      expect(result.resources[0].actions, hasLength(2));
      expect(result.resources[0].actions[0].type, equals("copy"));
      expect(result.resources[0].actions[1].type, equals("executable"));

      expect(result.resources[1].source, equals("dunst/dunstrc"));
      expect(
          result.resources[1].destination, equals("~/.config/dunst/dunstrc"));
      expect(result.resources[1].actions, hasLength(1));
    });

    test('parseConfig should correctly parse commands section', () {
      final result = parseConfig(configString);

      expect(result.commands, hasLength(2));
      expect(result.commands[0].name, equals("install-dependencies"));
      expect(result.commands[0].status, equals("completed"));
      expect(result.commands[0].timestamp, equals("2024-08-21T12:36:00Z"));
      expect(
          result.commands[0].parameters, equals(["i3", "dunst", "alacritty"]));

      expect(result.commands[1].name, equals("update-packages"));
      expect(result.commands[1].status, equals("completed"));
      expect(result.commands[1].timestamp, equals("2024-08-21T12:36:05Z"));
    });

    test('parseConfig should correctly parse packages section', () {
      final result = parseConfig(configString);

      expect(result.packages, hasLength(2));
      expect(result.packages[0].name, equals("i3"));
      expect(result.packages[0].manager, equals("apt"));
      expect(result.packages[0].version, equals("4.18.2-1"));
      expect(result.packages[0].scope, equals("global"));
      expect(result.packages[0].status, equals("installed"));
      expect(result.packages[0].timestamp, equals("2024-08-21T12:36:10Z"));

      expect(result.packages[1].name, equals("dunst"));
      expect(result.packages[1].manager, equals("pip"));
      expect(result.packages[1].version, equals("1.5.0"));
      expect(result.packages[1].scope, equals("config"));
      expect(result.packages[1].status, equals("installed"));
      expect(result.packages[1].timestamp, equals("2024-08-21T12:36:20Z"));
    });

    test('parseConfig should handle empty config', () {
      final emptyConfig = '';
      final result = parseConfig(emptyConfig);

      expect(result.resources, isEmpty);
      expect(result.commands, isEmpty);
      expect(result.packages, isEmpty);
    });

    test('parseConfig should handle config with only resources', () {
      final resourcesOnlyConfig = '''
resources {
  resource {
    source = "test/file"
    destination = "~/test/file"
  }
}
''';
      final result = parseConfig(resourcesOnlyConfig);

      expect(result.resources, hasLength(1));
      expect(result.commands, isEmpty);
      expect(result.packages, isEmpty);
    });

    test('parseConfig should handle file without actions', () {
      final noActionsConfig = '''
resources {
  resource {
    source = "test/file"
    destination = "~/test/file"
  }
}
''';
      final result = parseConfig(noActionsConfig);

      expect(result.resources, hasLength(1));
      expect(result.resources[0].actions, isEmpty);
    });

    test('parseConfig should handle command without parameters', () {
      final noParamsCommandConfig = '''
commands {
  command test-command {
    status = "completed"
    timestamp = "2024-08-21T12:36:00Z"
  }
}
''';
      final result = parseConfig(noParamsCommandConfig);

      expect(result.commands, hasLength(1));
      expect(result.commands[0].parameters, isEmpty);
    });
  });
}
