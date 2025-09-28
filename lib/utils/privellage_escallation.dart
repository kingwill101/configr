import 'dart:io';

abstract class PrivilegeEscalation {
  Future<ProcessResult> runWithElevatedPrivileges(
      String command, List<String> arguments);
}

class InteractiveSudoEscalation implements PrivilegeEscalation {
  @override
  Future<ProcessResult> runWithElevatedPrivileges(
      String command, List<String> arguments) async {
    // First, try running sudo with -n (non-interactive) to see if we have passwordless sudo
    var result = await Process.run('sudo', ['-n', command, ...arguments]);
    if (result.exitCode == 0) {
      return result;
    }

    // If passwordless sudo is not available, we need to ask for the password
    // Use stderr to avoid conflicts with CLI handler
    stderr.writeln('Sudo password required to run: $command ${arguments.join(' ')}');
    stderr.write('Password: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    stderr.writeln(''); // New line after password input

    // Use a shell to echo the password into sudo
    final fullCommand =
        'echo $password | sudo -S $command ${arguments.join(' ')}';
    result = await Process.run('sh', ['-c', fullCommand]);

    if (result.exitCode != 0) {
      throw Exception('Failed to run command with sudo: ${result.stderr}');
    }

    return result;
  }
}

class NonInteractiveSudoEscalation implements PrivilegeEscalation {
  @override
  Future<ProcessResult> runWithElevatedPrivileges(
      String command, List<String> arguments) async {
    // Try running sudo with -n (non-interactive) to see if we have passwordless sudo
    var result = await Process.run('sudo', ['-n', command, ...arguments]);
    if (result.exitCode == 0) {
      return result;
    }

    // If passwordless sudo is not available, throw an error instead of prompting
    throw Exception('Passwordless sudo required but not available. Please configure passwordless sudo or run with appropriate privileges.');
  }
}

class NoPrivilegeEscalation implements PrivilegeEscalation {
  @override
  Future<ProcessResult> runWithElevatedPrivileges(
      String command, List<String> arguments) async {
    // Run command directly without any privilege escalation
    return await Process.run(command, arguments);
  }
}
