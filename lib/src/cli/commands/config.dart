import 'package:configr/src/blocks/v2_apply.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'base_command.dart';

class ConfigCommand extends BaseCommand {
  @override
  String get name => 'config';

  @override
  String get description =>
      'Show resolved configuration (variables and secrets expanded)';

  @override
  Future<void> executeCommand() async {
    io.title('Resolved Configuration');

    try {
      final resolved = await runtime.resolveConfig();
      if (resolved == null) {
        io.error('Configuration file not found.');
        return;
      }

      _printResolvedConfig(resolved);
    } catch (e) {
      io.error('Config resolution failed: $e');
      logger.error('Config error: $e');
      rethrow;
    }
  }

  void _printResolvedConfig(ResolvedConfig resolved) {
    final formatter = i3.ConfigFormatter();
    final sensitiveKeys = resolved.sensitiveKeys;

    // Print resolved variables as set commands
    if (resolved.variables.isNotEmpty) {
      io.line('# Resolved variables');
      for (final entry in resolved.variables.entries) {
        final value = sensitiveKeys.contains(entry.key)
            ? '[REDACTED]'
            : entry.value;
        io.line('set \$${entry.key} "$value"');
      }
      io.line('');
    }

    // Print registered blocks with resolved properties
    if (resolved.blockRegistry.isNotEmpty) {
      io.line('# Resolved blocks');
      for (final typeEntry in resolved.blockRegistry.entries) {
        for (final idEntry in typeEntry.value.entries) {
          final id = idEntry.key;
          final props = idEntry.value;
          if (id != null) {
            io.line('${typeEntry.key} "$id" {');
          } else {
            io.line('${typeEntry.key} {');
          }
          for (final prop in props.entries) {
            final value = sensitiveKeys.contains(prop.key)
                ? '[REDACTED]'
                : prop.value.toString();
            io.line('  ${prop.key} = "$value"');
          }
          io.line('}');
          io.line('');
        }
      }
    }

    // Print the original config with variables resolved inline
    io.line('# Original (resolved) config');
    io.line(formatter.format(resolved.config).trimRight());
  }
}
