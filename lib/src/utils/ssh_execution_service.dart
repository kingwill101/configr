import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'execution_service.dart';

class SSHExecutionService implements ExecutionService {
  SSHClient? _client;
  SftpClient? _sftp;
  String _platform = 'linux';

  @override
  bool get isConnected => _client != null;

  @override
  String get platform => _platform;

  @override
  Future<void> connect(Map<String, dynamic> config) async {
    final host = config['host'] as String?;
    if (host == null || host.isEmpty) {
      throw ArgumentError('SSH host is required');
    }
    final port = config['port'] as int? ?? 22;
    final username = config['username'] as String? ?? 'root';
    final password = config['password'] as String?;
    final privateKeyPem = config['private_key'] as String?;
    final privateKeyPassphrase = config['private_key_passphrase'] as String?;

    final socket = await SSHSocket.connect(
      host,
      port,
      timeout: Duration(seconds: config['connect_timeout'] as int? ?? 30),
    );

    _client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: password != null ? () => password : null,
      identities: privateKeyPem != null
          ? SSHKeyPair.fromPem(privateKeyPem, privateKeyPassphrase)
          : null,
    );

    await _client!.authenticated;

    _sftp = await _client!.sftp();

    _platform = await _detectPlatform();
  }

  Future<String> _detectPlatform() async {
    try {
      final result = await run('uname', ['-s']);
      final os = result.stdout.toString().trim().toLowerCase();
      if (os.contains('darwin')) return 'macos';
      if (os.contains('linux')) return 'linux';
      if (os.contains('windows') || os.contains('mingw')) return 'windows';
      return 'linux';
    } catch (_) {
      return 'linux';
    }
  }

  @override
  Future<void> disconnect() async {
    _sftp?.close();
    _client?.close();
    _client = null;
    _sftp = null;
  }

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
    Map<String, String>? environment,
    CommandOutputHandler? onOutput,
    String? stdin,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    var cmd = runInShell
        ? _buildShellCommand(command, arguments)
        : '${command}${arguments.map((a) => ' ${_escapeArg(a)}').join()}';

    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      cmd = 'cd ${_escapeArg(workingDirectory)} && $cmd';
    }

    if (environment != null && environment.isNotEmpty) {
      final envVars = environment.entries
          .map((e) => '${e.key}=${_escapeArg(e.value)}')
          .join(' ');
      cmd = '$envVars $cmd';
    }

    final session = await client.execute(cmd);

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final stdoutDone = session.stdout
        .transform(const _Uint8ListCodec())
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stdoutBuf.writeln(line);
      onOutput?.call(line, false);
    }).catchError((_) {});

    final stderrDone = session.stderr
        .transform(const _Uint8ListCodec())
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stderrBuf.writeln(line);
      onOutput?.call(line, true);
    }).catchError((_) {});

    await Future.wait([stdoutDone, stderrDone]);

    await session.done;
    final exitCode = session.exitCode ?? -1;
    session.close();

    return ProcessResult(
      0,
      exitCode,
      stdoutBuf.toString(),
      stderrBuf.toString(),
    );
  }

  String _buildShellCommand(String command, List<String> arguments) {
    if (arguments.isEmpty) return command;
    final buf = StringBuffer(command);
    for (final arg in arguments) {
      buf.write(' ');
      buf.write(_escapeArg(arg));
    }
    return buf.toString();
  }

  String _escapeArg(String arg) {
    if (arg.contains(' ') || arg.contains(r'$') || arg.contains('"')) {
      return "'${arg.replaceAll("'", "'\\''")}'";
    }
    return arg;
  }

  @override
  Future<void> putFile(String sourcePath, String destinationPath) async {
    final sftp = _sftp;
    if (sftp == null) {
      throw StateError('SFTP not available. Call connect() first.');
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }

    final mode = SftpFileOpenMode.write |
        SftpFileOpenMode.create |
        SftpFileOpenMode.truncate;
    final file = await sftp.open(destinationPath, mode: mode);

    try {
      final bytes = await sourceFile.readAsBytes();
      await file.writeBytes(bytes);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {
    final sftp = _sftp;
    if (sftp == null) {
      throw StateError('SFTP not available. Call connect() first.');
    }

    final file = await sftp.open(sourcePath, mode: SftpFileOpenMode.read);
    final destFile = File(destinationPath);

    try {
      final bytes = await file.readBytes();
      await destFile.writeAsBytes(bytes);
    } finally {
      await file.close();
    }
  }
}

class _Uint8ListCodec extends Converter<Uint8List, List<int>> {
  const _Uint8ListCodec();

  @override
  List<int> convert(Uint8List input) => input;
}
