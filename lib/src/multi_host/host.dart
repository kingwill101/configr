/// Host model representing a target machine for configuration management.
///
/// A Host encapsulates all configuration needed to connect to and manage a
/// single machine, including connection parameters, discovered properties,
/// and metadata about the host role in the infrastructure.
///
/// At minimum, every host requires:
/// - A unique identifier (name)
/// - An address (IP or hostname)
/// - Connection credentials
///
/// Hosts can optionally belong to roles (web, db, worker, etc.) and groups
/// (production, staging, etc.) for targeted operations.
class Host {
  /// User-provided identifier for this host.
  ///
  /// Examples: "web-01", "db-master", "load-balancer-1"
  /// This is the key used to reference the host in variables and contexts.
  final String name;

  /// Network address or hostname to connect to this host.
  ///
  /// Examples: "10.0.0.1", "192.168.1.10", "db.example.com"
  final String address;

  /// Network port for SSH connection (defaults to 22).
  ///
  /// Examples: 22, 2222, 1234
  final int port;

  /// Username to authenticate with.
  ///
  /// Examples: "root", "admin", "centos"
  final String username;

  /// Optional SSH private key in PEM format.
  ///
  /// If not provided, the system will fall back to password authentication
  /// or SSH agent if available.
  final String? privateKey;

  /// Optional SSH private key passphrase for encrypted keys.
  final String? privateKeyPassphrase;

  /// Optional connection timeout in seconds.
  final int? connectTimeout;

  /// Dynamic variables discovered on this host.
  ///
  /// These include facts from gathered information, variables from
  /// inventory files, and computed variables from previous playbooks.
  /// Common examples: ansible_facts, ansible_host, ansible_user,
  /// network_info, system_info, or custom variables from config files.
  final Map<String, String> variables;

  /// Roles this host plays in the deployment topology.
  ///
  /// Roles are used by strategies to determine execution order and targets.
  /// Examples: ["web"], ["worker", "redis"], ["lb", "proxy"], []
  final List<String> roles;

  /// Host groups for targeted operations.
  ///
  /// Groups allow filtering hosts for operations (e.g., run only on
  /// production hosts). Examples: ["production"], ["eu-central"], []
  final List<String> groups;

  /// Connection configuration for SSH.
  ///
  /// Precomputed for efficiency, contains all connection parameters
  /// needed to establish a session with this host.
  final Map<String, dynamic> connectionConfig;

  const Host({
    required this.name,
    required this.address,
    this.port = 22,
    this.username = 'root',
    this.privateKey,
    this.privateKeyPassphrase,
    this.connectTimeout,
    this.variables = const {},
    this.roles = const [],
    this.groups = const [],
    this.connectionConfig = const {},
  });

  /// Convert host connection parameters to the format expected by
  /// [SSHExecutionService.connect].
  Map<String, dynamic> toConnectionMap() => {
    'host': address,
    'port': port,
    'username': username,
    if (privateKey != null) 'private_key': privateKey,
    if (privateKeyPassphrase != null)
      'private_key_passphrase': privateKeyPassphrase,
    if (connectTimeout != null) 'connect_timeout': connectTimeout,
  };

  /// Is this host part of a specific role?
  ///
  /// Useful for filtering hosts: isHostRole("web")
  bool isRole(String role) => roles.contains(role);

  /// Is this host part of a specific group?
  ///
  /// Useful for filtering hosts: isHostGroup("production")
  bool isGroup(String group) => groups.contains(group);

  /// Display-friendly string representation of the host.
  @override
  String toString() => 'Host(name: $name, address: $address)';

  /// Equality comparison based on host name.
  ///
  /// Two hosts with the same name are considered equal (assuming unique names
  /// in inventory). Used for sets and lookups.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Host && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
