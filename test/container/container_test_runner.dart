/// Distro-aware test tags and utilities.
///
/// Mark container integration tests with the appropriate tag so they
/// are only run inside the correct Docker image.
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'container_test_runner.dart';
///
/// void main() {
///   test('apt install works', () async {
///     // ...
///   }, tags: debianTag);
/// }
/// ```
const debianTag = 'debian';
const fedoraTag = 'fedora';
const archTag = 'arch';
const alpineTag = 'alpine';
const needsRootTag = 'needs-root';
const destructiveTag = 'destructive';

/// Returns true when running inside the expected test environment.
///
/// Non-container runs (CONFIGR_TEST_ENV unset) return true so tests
/// that don't need a real environment can still execute.
bool isEnv(String env) {
  const current = String.fromEnvironment('CONFIGR_TEST_ENV');
  return current.isEmpty || current == env;
}