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

    final socket = await SSHSocket.connect(
      host,
      config['port'] as int? ?? 22,
      timeout: Duration(seconds: config['connect_timeout'] as int? ?? 30),
    );

    final username = config['username'] as String? ?? 'root';
    final password = _nonEmpty(config['password'] as String?);
    final privateKeyPem = _nonEmpty(config['private_key'] as String?);
    final privateKeyPassphrase = _nonEmpty(
      config['private_key_passphrase'] as String?,
    );

    try {
      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: password == null ? null : () => password,
        identities: privateKeyPem == null
            ? null
            : SSHKeyPair.fromPem(privateKeyPem, privateKeyPassphrase),
        disableHostkeyVerification: true,
      );

      await _client!.authenticated;
      _sftp = await _client!.sftp();
      _platform = await _detectPlatform();
    } catch (_) {
      _client?.close();
      _client = null;
      rethrow;
    }
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

    var remoteCommand = _buildCommand(command, arguments);
    if (workingDirectory != null && workingDirectory.isNotEmpty) {
      remoteCommand = 'cd ${_escapeArg(workingDirectory)} && $remoteCommand';
    }
    if (environment != null && environment.isNotEmpty) {
      final envVars = environment.entries
          .map((entry) => '${entry.key}=${_escapeArg(entry.value)}')
          .join(' ');
      remoteCommand = '$envVars $remoteCommand';
    }

    final session = await client.execute(remoteCommand);
    if (stdin != null) {
      session.stdin.add(utf8.encode(stdin));
      await session.stdin.close();
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutDone = _collectOutput(session.stdout, stdoutBuffer, onOutput);
    final stderrDone = _collectOutput(
      session.stderr,
      stderrBuffer,
      onOutput == null ? null : (line, _) => onOutput(line, true),
    );

    await Future.wait([stdoutDone, stderrDone]);
    await session.done;

    final exitCode = session.exitCode ?? -1;
    session.close();

    return ProcessResult(
      0,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  }

  String _buildCommand(String command, List<String> arguments) {
    if (arguments.isEmpty) return command;
    return [command, ...arguments.map(_escapeArg)].join(' ');
  }

  String _escapeArg(String arg) {
    if (arg.isEmpty ||
        arg.contains(RegExp(r'''[\s$"`'\\]''')) ||
        arg.contains('&') ||
        arg.contains(';') ||
        arg.contains('|')) {
      return "'${arg.replaceAll("'", "'\\''")}'";
    }
    return arg;
  }

  Future<void> _collectOutput(
    Stream<Uint8List> stream,
    StringBuffer buffer,
    CommandOutputHandler? onOutput,
  ) async {
    final lines = stream
        .transform(const _Uint8ListCodec())
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      buffer.writeln(line);
      onOutput?.call(line, false);
    }
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

    final remoteFile = await sftp.open(
      destinationPath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );

    try {
      await remoteFile.writeBytes(await sourceFile.readAsBytes());
    } finally {
      await remoteFile.close();
    }
  }

  @override
  Future<void> fetchFile(String sourcePath, String destinationPath) async {
    final sftp = _sftp;
    if (sftp == null) {
      throw StateError('SFTP not available. Call connect() first.');
    }

    final remoteFile = await sftp.open(sourcePath, mode: SftpFileOpenMode.read);
    final destinationFile = File(destinationPath);

    try {
      await destinationFile.writeAsBytes(await remoteFile.readBytes());
    } finally {
      await remoteFile.close();
    }
  }

  String? _nonEmpty(String? value) {
    return value == null || value.isEmpty ? null : value;
  }
}

class _Uint8ListCodec extends Converter<Uint8List, List<int>> {
  const _Uint8ListCodec();

  @override
  List<int> convert(Uint8List input) => input;
}
