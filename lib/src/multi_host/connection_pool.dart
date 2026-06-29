import 'package:configr/src/multi_host/host.dart' show Host;
import 'package:configr/src/utils/ssh_execution_service.dart'
    show SSHExecutionService;

/// Manages SSH connections to multiple hosts for multi-host operations.
///
/// Each host gets one persistent SSH connection for the duration of a
/// multi-host operation. Connections are acquired on demand and released
/// when the operation on that host completes.
///
/// Example:
/// ```dart
/// final pool = ConnectionPool();
/// try {
///   final ssh = await pool.acquire(host);
///   await ssh.run('configr', ['apply', '/tmp/config']);
/// } finally {
///   await pool.release(host.name);
/// }
/// ```
class ConnectionPool {
  final Map<String, SSHExecutionService> _connections = {};
  final SSHExecutionService Function() _sshFactory;

  /// Maximum concurrent SSH connections. Set to 0 for unlimited.
  final int maxConnections;

  ConnectionPool({
    SSHExecutionService Function()? sshFactory,
    this.maxConnections = 0,
  }) : _sshFactory = sshFactory ?? (() => SSHExecutionService());

  /// Number of currently active connections.
  int get activeCount => _connections.length;

  /// Names of hosts with active connections.
  List<String> get connectedHosts => _connections.keys.toList();

  /// Acquire (or reuse) an SSH connection for [host].
  ///
  /// If a connection for this host already exists, it is reused. Otherwise
  /// a new connection is established using [Host.toConnectionMap].
  ///
  /// Throws if [maxConnections] is reached and no existing connection
  /// can be reused.
  Future<SSHExecutionService> acquire(Host host) async {
    final existing = _connections[host.name];
    if (existing != null) return existing;

    if (maxConnections > 0 && _connections.length >= maxConnections) {
      throw StateError(
        'Max connections ($maxConnections) reached. '
        'Release a connection before acquiring a new one.',
      );
    }

    final ssh = _sshFactory();
    await ssh.connect(host.toConnectionMap());
    _connections[host.name] = ssh;
    return ssh;
  }

  /// Release (disconnect) a connection for [hostName].
  ///
  /// Safe to call even if no connection exists for the given host.
  Future<void> release(String hostName) async {
    final ssh = _connections.remove(hostName);
    if (ssh != null) {
      await ssh.disconnect();
    }
  }

  /// Release all active connections.
  Future<void> releaseAll() async {
    final hosts = _connections.keys.toList();
    for (final hostName in hosts) {
      await release(hostName);
    }
  }
}
