import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;

/// Generates or removes system locales.
///
/// Supports a single locale name (`String`) or a list of locale names.
/// Currently implemented for Debian/Ubuntu and Arch Linux.
///
/// Supports list input and single-locale config.
/// /etc/locale.gen editing, locale-gen or localedef invocation.
abstract class LocaleGenBlock extends ActionBlock {
  @override
  String get blockType => 'locale_gen';

  List<String> locales = [];

  factory LocaleGenBlock() {
    final facts = OsFacts.detect();
    switch (facts.family) {
      case OsFamily.debian:
        return _DebianLocaleGenBlock();
      case OsFamily.arch:
        return _ArchLocaleGenBlock();
      default:
        return _UnsupportedLocaleGenBlock(facts);
    }
  }

  LocaleGenBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (locales.length == 1) 'name': locales.first,
  };

  @override
  void resetState() {
    super.resetState();
    locales = [];
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    final nameVar = context.getVariable('name');
    if (nameVar is String && nameVar.isNotEmpty) {
      locales = [nameVar];
    } else if (nameVar is List) {
      locales = nameVar.cast<String>();
    }

    final localesVar = context.getVariable('locales');
    if (localesVar is List) {
      locales = localesVar.cast<String>();
    } else if (localesVar is String && localesVar.isNotEmpty) {
      // i3config v2 may store array-like strings as comma-separated values,
      // so split on commas and trim each entry.
      locales = localesVar
          .split(',')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }
  }

  @override
  String dryRunSummary() {
    if (locales.isEmpty) return '';
    return '$blockType: ${locales.join(', ')}';
  }

  /// Validates locales against the SUPPORTED file if it exists.
  Future<void> validateAgainstSupported() async {
    final supportedFile = fileSystem.file('/usr/share/i18n/SUPPORTED');
    if (!await supportedFile.exists()) return;

    final supported = await supportedFile.readAsLines();
    final supportedLocales = supported
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split(RegExp(r'\s+')).first)
        .toSet();

    for (final locale in locales) {
      if (!supportedLocales.contains(locale)) {
        throw ActionFailedException(
          'Locale $locale is not in /usr/share/i18n/SUPPORTED',
          moduleId: id,
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Debian/Ubuntu — locale-gen + /etc/locale.gen
// ---------------------------------------------------------------------------

class _DebianLocaleGenBlock extends LocaleGenBlock {
  _DebianLocaleGenBlock() : super._();

  @override
  Future<void> execute() async {
    if (locales.isEmpty) {
      throw ActionFailedException('Name/locales is required for locale_gen', moduleId: id);
    }

    emitEvent(StartedEvent(moduleId: id, message: 'Generating locales: ${locales.join(', ')}'));

    try {
      final priv = privilegeEscalation;

      // Validate against SUPPORTED file
      await validateAgainstSupported();

      // Get already-generated locales
      final localeResult = await priv.runWithElevatedPrivileges('locale', ['-a']);
      final existingLocales = localeResult.stdout;

      final changedLocales = <String>[];

      for (final locale in locales) {
        if (existingLocales.contains(locale)) {
          emitEvent(StatusUpdateEvent(
            moduleId: id, message: 'Locale $locale already generated',
            level: StatusEvent.info,
          ));
          continue;
        }

        final localeGen = fileSystem.file('/etc/locale.gen');
        if (await localeGen.exists()) {
          String content = await localeGen.readAsString();
          final pattern = RegExp('#\\s*${RegExp.escape(locale)}', multiLine: true);
          if (content.contains(pattern)) {
            content = content.replaceAll(pattern, locale);
            await localeGen.writeAsString(content);
          } else if (!content.contains(locale)) {
            // Append to file
            content += '$locale\n';
            await localeGen.writeAsString(content);
          }
        } else {
          // locale.gen doesn't exist at all — create it
          await localeGen.create(recursive: true);
          await localeGen.writeAsString('$locale\n');
        }

        changedLocales.add(locale);
      }

      if (changedLocales.isNotEmpty && status != 'absent') {
        final result = await priv.runWithElevatedPrivileges('locale-gen', []);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'locale-gen failed: ${result.stderr}', moduleId: id,
          );
        }
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Locales processed: ${changedLocales.join(', ')}',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('locale_gen failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Arch Linux — /etc/locale.gen + locale-gen (same command)
// ---------------------------------------------------------------------------

class _ArchLocaleGenBlock extends LocaleGenBlock {
  _ArchLocaleGenBlock() : super._();

  @override
  Future<void> execute() async {
    if (locales.isEmpty) {
      throw ActionFailedException('Name/locales is required for locale_gen', moduleId: id);
    }

    emitEvent(StartedEvent(
      moduleId: id, message: 'Generating locales on Arch: ${locales.join(', ')}',
    ));

    try {
      final priv = privilegeEscalation;

      final changedLocales = <String>[];

      for (final locale in locales) {
        final localeGen = fileSystem.file('/etc/locale.gen');
        if (!await localeGen.exists()) {
          throw ActionFailedException(
            '/etc/locale.gen not found on Arch Linux', moduleId: id,
          );
        }

        if (status == 'absent') {
          final lines = await localeGen.readAsLines();
          final newLines = lines.where((l) => !l.contains(locale)).toList();
          if (lines.length != newLines.length) {
            await localeGen.writeAsString('${newLines.join('\n')}\n');
            changedLocales.add(locale);
          }
        } else {
          String content = await localeGen.readAsString();
          // Arch uses a comment prefix per locale line
          final pattern = RegExp('#?${RegExp.escape(locale)}', multiLine: true);
          if (content.contains(pattern)) {
            // Uncomment if commented
            content = content.replaceAll('#$locale', locale);
            await localeGen.writeAsString(content);
          } else {
            // Append locale
            content += '\n$locale\n';
            await localeGen.writeAsString(content);
          }
          changedLocales.add(locale);
        }
      }

      if (changedLocales.isNotEmpty && status != 'absent') {
        final result = await priv.runWithElevatedPrivileges('locale-gen', []);
        if (result.exitCode != 0) {
          throw ActionFailedException(
            'locale-gen failed on Arch: ${result.stderr}', moduleId: id,
          );
        }
      }

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Locales processed on Arch: ${changedLocales.join(', ')}',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('locale_gen failed on Arch: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}

// ---------------------------------------------------------------------------
// Unsupported OS placeholder — throws on execute, not construction
// ---------------------------------------------------------------------------

class _UnsupportedLocaleGenBlock extends LocaleGenBlock {
  _UnsupportedLocaleGenBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'locale_gen is only supported on Debian/Ubuntu and Arch Linux. '
      'Detected: ${_facts.family.name}.',
    );
  }

  @override
  Future<void> rollback() async {}
}
