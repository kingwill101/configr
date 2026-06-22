import 'package:i3config/i3config_v2.dart' as i3;

/// Tests various edge cases for the i3config v2 parser.
void main() {
  // Test 1: Comment inside block
  final config1 = '''
resource {
  type "file"
  actions {
    copy {
      # This is a comment inside a block
    }
  }
}
''';
  try {
    final parsed = i3.Config.parse(config1);
    print('✅ Test 1 (comment inside block): Parsed OK');
    print('  Statements: ${parsed.statements.length}');
  } catch (e) {
    print('❌ Test 1 (comment inside block): $e');
  }

  // Test 2: Unknown action type inside actions
  final config2 = '''
resource {
  type "file"
  actions {
    copy {}
    cleanup {}
  }
}
''';
  try {
    final parsed = i3.Config.parse(config2);
    print('✅ Test 2 (unknown action type): Parsed OK');
    print('  Statements: ${parsed.statements.length}');
  } catch (e) {
    print('❌ Test 2 (unknown action type): $e');
  }

  // Test 3: Multiple resources with comments
  final config3 = '''
resource {
  type "file"
  actions {
    copy {}
  }
}

# Another resource
resource {
  type "file"
  actions {
    copy {}
  }
}
''';
  try {
    final parsed = i3.Config.parse(config3);
    print('✅ Test 3 (multiple resources): Parsed OK');
    print('  Statements: ${parsed.statements.length}');
  } catch (e) {
    print('❌ Test 3 (multiple resources): $e');
  }

  // Test 4: Command-style properties (no = sign)
  final config4 = '''
resource {
  type "file"
  source "/tmp/foo"
  destination "/tmp/bar"
}
''';
  try {
    final parsed = i3.Config.parse(config4);
    print('✅ Test 4 (command-style properties): Parsed OK');
    print('  Statements: ${parsed.statements.length}');
  } catch (e) {
    print('❌ Test 4 (command-style properties): $e');
  }

  // Test 5: Full _test_parse config
  final config5 = r'''
# Example: Resource with actions
resource {
  type "file"
  source "app_config.yml"
  destination "/etc/myapp/config.yml"
  require_root = true

  actions {
    copy {
    }
    permissions {
      mode "644"
    }
    backup {
    }
  }
}

# Another resource
resource {
  type "file"
  source "temp_config.yml"
  destination "/tmp/config.yml"
  require_root = false

  actions {
    copy {
    }
    permissions {
      mode "644"
      require_root = true
    }
    cleanup {
    }
  }
}

# Third resource
resource {
  type "file"
  source "service_config.yml"
  destination "/etc/service/config.yml"
}
''';
  try {
    final parsed = i3.Config.parse(config5);
    print('✅ Test 5 (full config): Parsed OK');
    print('  Statements: ${parsed.statements.length}');
  } catch (e) {
    print('❌ Test 5 (full config): $e');
  }
}
