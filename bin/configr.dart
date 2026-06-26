// Configr CLI entry point.
//
// This is the executable that `dart run configr` resolves to.
// Command implementations are in cli/commands/.
//
// Thin wrapper around [ConfigrCommandRunner] from lib. Catches
// [CliExitException] to translate to process exit codes without
// crashing tests that invoke the runner directly.

import 'dart:io';

import 'package:configr/src/cli/configr_command_runner.dart';
import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/utils/logging.dart';

void main(List<String> arguments) async {
  final runner = ConfigrCommandRunner();

  try {
    await runner.run(arguments);
  } on CliExitException catch (e) {
    exit(e.exitCode);
  } on FormatException catch (e) {
    print('Configuration Error: ${e.message}');
    print('Tip: Check your configuration file syntax and format');
    exit(1);
  } on FileSystemException catch (e) {
    print('File System Error: ${e.message}');
    print('Tip: Check file permissions and paths: ${e.path}');
    exit(1);
  } on ProcessException catch (e) {
    print('Process Error: ${e.message}');
    print('Tip: Make sure required commands are installed and accessible');
    exit(1);
  } on ArgumentError catch (e) {
    print('Argument Error: ${e.message}');
    print('Tip: Check command arguments and options');
    exit(1);
  } catch (e, stackTrace) {
    print('Unexpected Error: $e');
    print('Tip: Use --debug flag for detailed error information');
    logger.error('Unexpected error: $e', e, stackTrace);
    exit(1);
  }
}
