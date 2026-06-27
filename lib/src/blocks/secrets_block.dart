import 'dart:async';

import 'package:configr/src/secrets/secret_provider.dart';
import 'package:configr/src/secrets/secret_providers.dart';
import 'package:configr/src/secrets/secret_resolver.dart';
import 'package:configr/src/secrets/providers/providers.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class SecretsBlock extends i3.BaseBlockHandler {
  final Map<String, String> _aliases = {};
  String? _profile;
  final SecretProviders _providers;

  SecretsBlock()
    : _providers = _createDefaultProviders();

  static SecretProviders _createDefaultProviders() {
    final providers = SecretProviders();
    providers.register('env', (_) => const EnvProvider());
    providers.register('file', (_) => const FileProvider());
    providers.register('dotenv', (_) => const DotenvProvider());
    providers.register('cmd', (_) => const CmdProvider());
    providers.register('onepassword', (_) => const OnePasswordProvider());
    providers.register('keyring', (_) => const KeyringProvider());
    providers.register('bitwarden', (_) => const BitwardenProvider());
    providers.register('aws', (_) => const AwsSecretsManagerProvider());
    providers.register('gcp', (_) => const GcpSecretManagerProvider());
    providers.register('doppler', (_) => const DopplerProvider());
    return providers;
  }

  @override
  String get blockType => 'secrets';

  @override
  void registerScopedCommands(i3.BlockHandlerRegistry registry) {
    registry.registerCommand('provider', _ProviderCommandHandler(this));
  }

  @override
  FutureOr<void> handle(i3.Block block, i3.Context context) {}

  @override
  FutureOr<void> afterChildrenProcessed(
    i3.Block block,
    i3.Context context,
  ) async {
    _profile = context.getVariable('profile') as String?;

    final resolver = SecretResolver(_providers);
    final rawValues = <String, String>{};
    final sensitiveKeys = <String>{};

    for (final entry in context.variables.entries) {
      final key = entry.key;
      if (key == 'profile') continue;
      if (key.startsWith('provider_')) continue;

      final uriString = entry.value.toString();
      final result = await resolver.resolveWithSensitivity(
        uriString,
        aliases: _aliases,
        markSensitive: true,
      );
      if (result == null) continue;

      if (result is SensitiveValue) {
        rawValues[key] = result.value;
        sensitiveKeys.add(key);
      } else {
        rawValues[key] = result as String;
      }
    }

    if (rawValues.isNotEmpty) {
      context.globalContext.registerBlock('secrets', null, rawValues);
      final existingKeys = (context.globalContext.options['_sensitiveKeys']
          as Set<String>? ?? {});
      context.globalContext.options['_sensitiveKeys'] =
        {...existingKeys, ...sensitiveKeys};
      final existingValues = (context.globalContext.options['_sensitiveValues']
          as Map<String, String>? ?? {});
      context.globalContext.options['_sensitiveValues'] = {
        ...existingValues,
        for (final k in sensitiveKeys) k: rawValues[k]!,
      };
      for (final entry in rawValues.entries) {
        context.setVariable('secrets_${entry.key}', entry.value);
        context.globalContext.setVariable(
          'secrets_${entry.key}',
          entry.value,
        );
        context.globalContext.setVariable(
          'secrets.${entry.key}',
          entry.value,
        );
      }
    }
  }

  Map<String, String> get aliases => Map.unmodifiable(_aliases);
  String? get profile => _profile;
}

class _ProviderCommandHandler extends i3.BaseCommandHandler<void> {
  final SecretsBlock _block;

  _ProviderCommandHandler(this._block);

  @override
  String get commandName => 'provider';

  @override
  FutureOr<void> handle(i3.Command command, i3.Context context) {
    if (command.args.length >= 3) {
      final alias = getArgAsString(command, 0, context);
      final eq = getArgAsString(command, 1, context);
      if (eq == '=') {
        final uri = getArgAsString(command, 2, context);
        if (alias.isNotEmpty && uri.isNotEmpty) {
          _block._aliases[alias] = uri;
        }
      }
    }
  }
}
