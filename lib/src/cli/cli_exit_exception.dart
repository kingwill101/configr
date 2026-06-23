class CliExitException implements Exception {
  final int exitCode;
  const CliExitException(this.exitCode);

  @override
  String toString() => 'CliExitException($exitCode)';
}
