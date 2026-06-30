import 'package:configr/src/cli/cli_exit_exception.dart';

extension CliExitExceptionSupport on Exception {
  CliExitException get asCliExit {
    if (this is CliExitException) {
      return this as CliExitException;
    }

    if (this is FormatException) {
      return const CliExitException(1);
    }

    if (this is StateError) {
      return const CliExitException(2);
    }

    return const CliExitException(1);
  }
}
