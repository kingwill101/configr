/// Build metadata embedded by `dart compile -D...`.
///
/// Local development builds use stable defaults. CI builds override these
/// values so downloaded binaries can report exactly where they came from.
class ConfigrBuildInfo {
  const ConfigrBuildInfo._();

  static const version = String.fromEnvironment(
    'CONFIGR_VERSION',
    defaultValue: 'dev',
  );
  static const gitSha = String.fromEnvironment(
    'CONFIGR_GIT_SHA',
    defaultValue: 'unknown',
  );
  static const gitShortSha = String.fromEnvironment(
    'CONFIGR_GIT_SHORT_SHA',
    defaultValue: 'unknown',
  );
  static const buildDate = String.fromEnvironment(
    'CONFIGR_BUILD_DATE',
    defaultValue: 'unknown',
  );
  static const buildNumber = String.fromEnvironment(
    'CONFIGR_BUILD_NUMBER',
    defaultValue: 'local',
  );
  static const buildRef = String.fromEnvironment(
    'CONFIGR_BUILD_REF',
    defaultValue: 'local',
  );
  static const buildSource = String.fromEnvironment(
    'CONFIGR_BUILD_SOURCE',
    defaultValue: 'local',
  );
  static const buildTarget = String.fromEnvironment(
    'CONFIGR_BUILD_TARGET',
    defaultValue: 'unknown',
  );
  static const gitDirty = bool.fromEnvironment(
    'CONFIGR_GIT_DIRTY',
    defaultValue: false,
  );

  static String get displayVersion {
    if (gitShortSha == 'unknown') return version;
    return '$version+$gitShortSha';
  }

  static List<String> get lines => [
    'configr $displayVersion',
    'version: $version',
    'gitSha: $gitSha',
    'gitDirty: $gitDirty',
    'buildDate: $buildDate',
    'buildNumber: $buildNumber',
    'buildRef: $buildRef',
    'buildSource: $buildSource',
    'buildTarget: $buildTarget',
  ];
}
