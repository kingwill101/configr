class ConnectionConfig {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;
  final int connectTimeout;

  const ConnectionConfig({
    required this.host,
    this.port = 22,
    this.username = 'root',
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
    this.connectTimeout = 30,
  });

  Map<String, dynamic> toMap() => {
    'host': host,
    'port': port,
    'username': username,
    if (password != null) 'password': password,
    if (privateKey != null) 'private_key': privateKey,
    if (privateKeyPassphrase != null)
      'private_key_passphrase': privateKeyPassphrase,
    'connect_timeout': connectTimeout,
  };
}
