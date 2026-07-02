// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:dartssh2/src/ssh_hostkey.dart';
import 'package:ffi/ffi.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file_sftp/file_sftp.dart' show SftpConfig, SftpFileSystem;
import 'package:lualike/lualike.dart' show ProcessBackend;
import 'package:process_lualike/process_lualike.dart' show SshProcessBackend;

import 'execution_service.dart';

// ── POSIX socket FFI bindings (Linux / macOS) ────────────────────────

const _afUnix = 1;
const _sockStream = 1;

typedef _SocketNative =
    Int32 Function(Int32 domain, Int32 type, Int32 protocol);
typedef _SocketDart = int Function(int domain, int type, int protocol);

typedef _ConnectNative =
    Int32 Function(Int32 socket, Pointer<Void> address, Uint32 addressLength);
typedef _ConnectDart =
    int Function(int socket, Pointer<Void> address, int addressLength);

typedef _ReadNative =
    IntPtr Function(Int32 socket, Pointer<Void> buffer, IntPtr count);
typedef _ReadDart = int Function(int socket, Pointer<Void> buffer, int count);

typedef _WriteNative =
    IntPtr Function(Int32 socket, Pointer<Void> buffer, IntPtr count);
typedef _WriteDart = int Function(int socket, Pointer<Void> buffer, int count);

typedef _CloseNative = Int32 Function(Int32 socket);
typedef _CloseDart = int Function(int socket);

DynamicLibrary _loadLibc() {
  if (Platform.isWindows) {
    throw UnsupportedError('POSIX socket FFI is not available on Windows.');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('/usr/lib/libSystem.B.dylib');
  }
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libc.so');
  }
  return DynamicLibrary.open('libc.so.6');
}

final DynamicLibrary? _libc = Platform.isWindows ? null : _loadLibc();

final _SocketDart? _socket = _libc?.lookupFunction<_SocketNative, _SocketDart>(
  'socket',
);
final _ConnectDart? _connect = _libc
    ?.lookupFunction<_ConnectNative, _ConnectDart>('connect');
final _ReadDart? _read = _libc?.lookupFunction<_ReadNative, _ReadDart>('read');
final _WriteDart? _write = _libc?.lookupFunction<_WriteNative, _WriteDart>(
  'write',
);
final _CloseDart? _close = _libc?.lookupFunction<_CloseNative, _CloseDart>(
  'close',
);

// ── SSH execution service ────────────────────────────────────────────

class SSHExecutionService implements ExecutionService {
  SSHClient? _client;
  SftpClient? _sftp;
  SftpFileSystem? _fileSystem;
  String _platform = 'linux';

  FileSystem get fileSystem => _fileSystem ??= SftpFileSystem.fromClient(
    _sftp!,
    config: () => SftpConfig(host: '', username: '', root: '/'),
  );

  ProcessBackend? get processBackend {
    final client = _client;
    if (client == null) return null;
    return SshProcessBackend(client);
  }

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
      List<SSHKeyPair>? identities;
      if (privateKeyPem != null) {
        identities = SSHKeyPair.fromPem(privateKeyPem, privateKeyPassphrase);
      } else {
        identities = _agentIdentities();
      }

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: password == null ? null : () => password,
        identities: identities,
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
    // 1. Try uname -s (Git Bash / MSYS2 / Cygwin / WSL)
    try {
      final result = await run('uname', ['-s']);
      final os = result.stdout.toString().trim().toLowerCase();
      if (os.contains('darwin')) return 'macos';
      if (os.contains('linux')) return 'linux';
      if (os.contains('windows') ||
          os.contains('mingw') ||
          os.contains('cygwin')) {
        return 'windows';
      }
    } catch (_) {}

    // 2. Try cmd /c ver — always available on native Windows OpenSSH
    try {
      final result = await run('cmd', ['/c', 'ver']);
      if (result.exitCode == 0 &&
          result.stdout.toString().toLowerCase().contains('windows')) {
        return 'windows';
      }
    } catch (_) {}

    // 3. Try PowerShell — reliable indicator of Windows
    try {
      final result = await run('powershell', [
        '-NoProfile',
        '-Command',
        '\$PSVersionTable.PSVersion',
      ]);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        return 'windows';
      }
    } catch (_) {}

    return 'linux';
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
      if (_platform == 'windows') {
        remoteCommand =
            'cd /d ${_quoteWindows(workingDirectory)} && $remoteCommand';
      } else {
        remoteCommand = 'cd ${_escapeArg(workingDirectory)} && $remoteCommand';
      }
    }
    if (environment != null && environment.isNotEmpty) {
      if (_platform == 'windows') {
        final envCmds = environment.entries
            .map((entry) => 'set "${entry.key}=${entry.value}"')
            .join(' && ');
        remoteCommand = '$envCmds && $remoteCommand';
      } else {
        final envVars = environment.entries
            .map((entry) => '${entry.key}=${_escapeArg(entry.value)}')
            .join(' ');
        remoteCommand = '$envVars $remoteCommand';
      }
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
    if (_platform == 'windows') {
      return _escapeArgWindows(arg);
    }
    return _escapeArgPosix(arg);
  }

  /// POSIX shell quoting (sh/bash-compatible).
  /// Wraps the arg in single quotes; embeds a literal single quote as `'\''`
  /// (end-quote, escaped literal quote, resume-quote).
  String _escapeArgPosix(String arg) {
    if (arg.isEmpty ||
        arg.contains(RegExp(r'''[\s$"`'\\]''')) ||
        arg.contains('&') ||
        arg.contains(';') ||
        arg.contains('|')) {
      return "'${arg.replaceAll("'", "'\\''")}'";
    }
    return arg;
  }

  /// Windows cmd.exe quoting.
  /// Wraps the arg in double quotes; embeds a literal double quote as `""`.
  /// This works for cmd.exe and is harmless for PowerShell -Command.
  String _escapeArgWindows(String arg) {
    if (arg.isEmpty || arg.contains(RegExp(r'[\s"&|<>^%]'))) {
      return _quoteWindows(arg);
    }
    return arg;
  }

  String _quoteWindows(String arg) => '"${arg.replaceAll('"', '""')}"';

  Future<void> _collectOutput(
    Stream<Uint8List> stream,
    StringBuffer buffer,
    CommandOutputHandler? onOutput,
  ) async {
    final lines = stream
        .map<List<int>>((chunk) => chunk)
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

  // ── SSH Agent support ──────────────────────────────────────────────

  /// Try to load identities from the SSH agent via SSH_AUTH_SOCK.
  /// Falls back to ~/.1password/agent.sock when env var socket has no identities.
  List<SSHKeyPair>? _agentIdentities() {
    final primaryPath = _resolveAgentPath();
    if (primaryPath != null) {
      final pairs = buildAgentBackedKeyPairs(agentPath: primaryPath);
      if (pairs.isNotEmpty) return pairs;
    }

    // Fallback: try 1Password SSH agent socket
    try {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final fallbackPath = '$home/.1password/agent.sock';
        if (fallbackPath != primaryPath) {
          final pairs = buildAgentBackedKeyPairs(agentPath: fallbackPath);
          if (pairs.isNotEmpty) return pairs;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _resolveAgentPath() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return r'\\.\pipe\openssh-ssh-agent';
    }
    return env['SSH_AUTH_SOCK'];
  }
}

// ── Agent-backed SSH key pair ────────────────────────────────────────

List<SSHKeyPair> buildAgentBackedKeyPairs({required String agentPath}) {
  final identities = listAgentIdentitiesSync(agentPath: agentPath);
  if (identities.isEmpty) return const [];

  return identities
      .map(
        (identity) => AgentBackedKeyPair.fromPublicKey(
          agentPath: agentPath,
          publicKeyBlob: identity.publicKey,
        ),
      )
      .toList(growable: false);
}

class AgentIdentity {
  const AgentIdentity({required this.publicKey, required this.comment});
  final Uint8List publicKey;
  final String comment;
}

List<AgentIdentity> listAgentIdentitiesSync({required String agentPath}) {
  final response = _sendAgentRequestSync(
    agentPath: agentPath,
    payload: Uint8List.fromList([SSHAgentProtocol.requestIdentities]),
  );
  final reader = _BinaryReader(response);
  final messageType = reader.readUint8();
  if (messageType == SSHAgentProtocol.failure) return const [];
  if (messageType != SSHAgentProtocol.identitiesAnswer) return const [];

  final count = reader.readUint32();
  final identities = <AgentIdentity>[];
  for (var i = 0; i < count; i++) {
    identities.add(
      AgentIdentity(publicKey: reader.readString(), comment: reader.readUtf8()),
    );
  }
  return identities;
}

Uint8List agentSignSync({
  required String agentPath,
  required Uint8List publicKey,
  required Uint8List data,
  int flags = 0,
}) {
  final writer = _BytesBuilder(copy: false)
    ..addByte(SSHAgentProtocol.signRequest)
    ..add(_encodeString(publicKey))
    ..add(_encodeString(data))
    ..add(_encodeUint32(flags));
  final response = _sendAgentRequestSync(
    agentPath: agentPath,
    payload: writer.takeBytes(),
  );
  final reader = _BinaryReader(response);
  final messageType = reader.readUint8();
  if (messageType == SSHAgentProtocol.failure) {
    throw StateError('SSH agent refused to sign with the selected key.');
  }
  if (messageType != SSHAgentProtocol.signResponse) {
    throw StateError('Unexpected SSH agent response type: $messageType');
  }
  return reader.readString();
}

Uint8List _sendAgentRequestSync({
  required String agentPath,
  required Uint8List payload,
}) {
  if (Platform.isWindows || agentPath.startsWith(r'\\.\pipe\')) {
    throw UnsupportedError(
      'Windows SSH agent support requires the win32 package.',
    );
  }
  return _sendUnixSocketRequestSync(agentPath: agentPath, payload: payload);
}

Uint8List _sendUnixSocketRequestSync({
  required String agentPath,
  required Uint8List payload,
}) {
  final pathBytes = Uint8List.fromList(utf8.encode(agentPath));
  if (pathBytes.isEmpty) {
    throw ArgumentError.value(agentPath, 'agentPath', 'must not be empty');
  }

  final socket = _socket;
  final connect = _connect;
  final close = _close;
  if (socket == null || connect == null || close == null) {
    throw UnsupportedError(
      'POSIX socket FFI is not available on this platform.',
    );
  }

  final socketHandle = socket(_afUnix, _sockStream, 0);
  if (socketHandle < 0) {
    throw SocketException('Failed to open SSH agent Unix socket.');
  }

  final addressLength = pathBytes.length + 3;
  final addressBuffer = calloc<Uint8>(addressLength);
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      addressBuffer[0] = addressLength;
      addressBuffer[1] = _afUnix;
      addressBuffer
          .asTypedList(addressLength)
          .setRange(2, 2 + pathBytes.length, pathBytes);
    } else {
      addressBuffer.cast<Uint16>().value = _afUnix;
      addressBuffer
          .asTypedList(addressLength)
          .setRange(2, 2 + pathBytes.length, pathBytes);
    }

    final connectResult = connect(
      socketHandle,
      addressBuffer.cast<Void>(),
      addressLength,
    );
    if (connectResult != 0) {
      throw SocketException('Failed to connect to SSH agent socket.');
    }

    final framedPayload = Uint8List.fromList([
      ..._encodeUint32(payload.length),
      ...payload,
    ]);
    _writeAllSync(socketHandle, framedPayload);
    final responseLength = _readUint32Sync(socketHandle);
    return _readExactSync(socketHandle, responseLength);
  } finally {
    calloc.free(addressBuffer);
    close(socketHandle);
  }
}

void _writeAllSync(int socketHandle, Uint8List bytes) {
  final write = _write;
  if (write == null) {
    throw UnsupportedError(
      'POSIX socket FFI is not available on this platform.',
    );
  }

  final pointer = calloc<Uint8>(bytes.length);
  try {
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    var offset = 0;
    while (offset < bytes.length) {
      final written = write(
        socketHandle,
        (pointer + offset).cast<Void>(),
        bytes.length - offset,
      );
      if (written <= 0) {
        throw SocketException('Failed to write to SSH agent socket.');
      }
      offset += written;
    }
  } finally {
    calloc.free(pointer);
  }
}

Uint8List _readExactSync(int socketHandle, int length) {
  final read = _read;
  if (read == null) {
    throw UnsupportedError(
      'POSIX socket FFI is not available on this platform.',
    );
  }

  final buffer = Uint8List(length);
  final pointer = calloc<Uint8>(length);
  try {
    var offset = 0;
    while (offset < length) {
      final readCount = read(
        socketHandle,
        (pointer + offset).cast<Void>(),
        length - offset,
      );
      if (readCount <= 0) {
        throw SocketException('Failed to read from SSH agent socket.');
      }
      offset += readCount;
    }
    buffer.setAll(0, pointer.asTypedList(length));
    return buffer;
  } finally {
    calloc.free(pointer);
  }
}

int _readUint32Sync(int socketHandle) {
  final header = _readExactSync(socketHandle, 4);
  return ByteData.sublistView(header).getUint32(0);
}

class AgentBackedKeyPair implements SSHKeyPair {
  AgentBackedKeyPair({
    required this.agentPath,
    required this.publicKeyBlob,
    required this.publicKey,
    required this.name,
    required this.type,
  });

  factory AgentBackedKeyPair.fromPublicKey({
    required String agentPath,
    required Uint8List publicKeyBlob,
  }) {
    final publicKey = _decodePublicKey(publicKeyBlob);
    final publicKeyType = _readEncodedType(publicKeyBlob);
    final signatureType = switch (publicKeyType) {
      SSHRsaPublicKey.type => SSHRsaSignatureType.sha256,
      _ => publicKeyType,
    };
    return AgentBackedKeyPair(
      agentPath: agentPath,
      publicKeyBlob: publicKeyBlob,
      publicKey: publicKey,
      name: publicKeyType,
      type: signatureType,
    );
  }

  final String agentPath;
  final Uint8List publicKeyBlob;
  final SSHHostKey publicKey;

  @override
  final String name;

  @override
  final String type;

  @override
  SSHHostKey toPublicKey() => publicKey;

  @override
  SSHSignature sign(Uint8List data) {
    final signature = agentSignSync(
      agentPath: agentPath,
      publicKey: publicKeyBlob,
      data: data,
      flags: _signatureFlagsForType(type),
    );
    return _decodeSignature(signature);
  }

  @override
  String toPem() {
    throw UnsupportedError('Agent-backed SSH keys cannot be exported as PEM.');
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

SSHHostKey _decodePublicKey(Uint8List publicKeyBlob) {
  final publicKeyType = _readEncodedType(publicKeyBlob);
  return switch (publicKeyType) {
    SSHRsaPublicKey.type => SSHRsaPublicKey.decode(publicKeyBlob),
    SSHEd25519PublicKey.type => SSHEd25519PublicKey.decode(publicKeyBlob),
    _ when publicKeyType.startsWith('ecdsa-sha2-') => SSHEcdsaPublicKey.decode(
      publicKeyBlob,
    ),
    _ => throw UnsupportedError(
      'Unsupported SSH public key type: $publicKeyType',
    ),
  };
}

SSHSignature _decodeSignature(Uint8List signatureBlob) {
  final signatureType = _readEncodedType(signatureBlob);
  return switch (signatureType) {
    SSHRsaSignatureType.sha1 ||
    SSHRsaSignatureType.sha256 ||
    SSHRsaSignatureType.sha512 => SSHRsaSignature.decode(signatureBlob),
    SSHEd25519Signature.type => SSHEd25519Signature.decode(signatureBlob),
    _ when signatureType.startsWith('ecdsa-sha2-') => SSHEcdsaSignature.decode(
      signatureBlob,
    ),
    _ => throw UnsupportedError(
      'Unsupported SSH signature type: $signatureType',
    ),
  };
}

String _readEncodedType(Uint8List blob) {
  return _BinaryReader(blob).readUtf8();
}

int _signatureFlagsForType(String type) {
  return switch (type) {
    SSHRsaSignatureType.sha256 => SSHAgentProtocol.rsaSha2_256,
    SSHRsaSignatureType.sha512 => SSHAgentProtocol.rsaSha2_512,
    _ => 0,
  };
}

Uint8List _encodeUint32(int value) {
  final data = ByteData(4)..setUint32(0, value);
  return data.buffer.asUint8List();
}

Uint8List _encodeString(Uint8List value) {
  return Uint8List.fromList([..._encodeUint32(value.length), ...value]);
}

class _BytesBuilder {
  _BytesBuilder({this.copy = true});
  final bool copy;
  final _chunks = <Uint8List>[];
  int _length = 0;

  void addByte(int byte) {
    _chunks.add(Uint8List.fromList([byte]));
    _length++;
  }

  void add(Uint8List bytes) {
    _chunks.add(bytes);
    _length += bytes.length;
  }

  Uint8List takeBytes() {
    final result = Uint8List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear();
    _length = 0;
    return result;
  }
}

class _BinaryReader {
  _BinaryReader(this.bytes);
  final Uint8List bytes;
  int _offset = 0;

  int readUint8() {
    final value = bytes[_offset];
    _offset += 1;
    return value;
  }

  int readUint32() {
    final value = ByteData.sublistView(
      bytes,
      _offset,
      _offset + 4,
    ).getUint32(0);
    _offset += 4;
    return value;
  }

  Uint8List readString() {
    final length = readUint32();
    final value = bytes.sublist(_offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(value);
  }

  String readUtf8() => utf8.decode(readString());
}
