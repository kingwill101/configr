import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/network_service.dart' show NetworkRequest;
import 'package:configr/src/utils/shell_type.dart';

/// Result of running a command through a [NetworkStrategy].
class CommandScript {
  final String executable;
  final List<String> args;
  final String? stdin;
  const CommandScript(this.executable, this.args, [this.stdin]);
}

/// Platform-specific network command factory.
///
/// Generates shell/PowerShell commands for network operations
/// that can be executed via [ExecutionService].
abstract class NetworkStrategy {
  const NetworkStrategy();

  /// Create the appropriate strategy for [platform].
  factory NetworkStrategy.forPlatform(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('windows')) {
      return const WindowsNetworkStrategy();
    }
    return const UnixNetworkStrategy();
  }

  /// Build command for an HTTP request.
  CommandScript httpRequestScript(NetworkRequest request);

  /// Build command for DNS resolution of [host].
  CommandScript dnsResolveScript(String host);

  /// Build command for a TCP connectivity probe to [host]:[port].
  CommandScript tcpProbeScript(String host, int port, int timeoutSeconds);

  /// Build command for downloading [url] to [dest] with progress tracking.
  /// Returns `null` for [stdin] when no script body is needed.
  CommandScript downloadScript({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    required Map<String, String> headers,
    required bool resume,
  });

  /// Build command for a ping probe to [host].
  CommandScript pingProbeScript(String host, int timeoutSeconds);

  /// Build command for capability detection.
  CommandScript capabilityDetectionScript();
}

/// Unix implementation using sh/bash with curl, getent, nc, etc.
class UnixNetworkStrategy extends NetworkStrategy {
  const UnixNetworkStrategy();

  static String _sh(String value) {
    if (value.isEmpty) return "''";
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  static String _curlHeaderArgs(Map<String, String> headers) {
    return headers.entries
        .map((e) => '-H ${_sh('${e.key}: ${e.value}')} ')
        .join();
  }

  @override
  CommandScript httpRequestScript(NetworkRequest request) {
    final bodyPath =
        '/tmp/configr_uri_${DateTime.now().microsecondsSinceEpoch}';
    final headers = _curlHeaderArgs(request.headers);
    final command = StringBuffer()
      ..write('status=\$(curl -sS -m ${request.timeoutSeconds} ')
      ..write(request.validateCertificates ? '' : '-k ')
      ..write('-X ${_sh(request.method)} ')
      ..write(headers)
      ..write(request.body.isEmpty ? '' : '--data-binary ${_sh(request.body)} ')
      ..write('-o ${_sh(bodyPath)} -w "%{http_code}" ')
      ..write(_sh(request.uri.toString()))
      ..write(
        '); code=\$?; body=\$(cat ${_sh(bodyPath)} 2>/dev/null || true); ',
      )
      ..write('rm -f ${_sh(bodyPath)}; ')
      ..write('printf "%s\\n%s" "\$status" "\$body"; exit "\$code"');

    return CommandScript(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(command.toString()),
    );
  }

  @override
  CommandScript dnsResolveScript(String host) {
    final script =
        '''
getent hosts ${_sh(host)} | awk '{print \$1; exit}' 2>/dev/null ||
  nslookup ${_sh(host)} 2>/dev/null | awk '/^Address: / {print \$2; exit}' ||
  host ${_sh(host)} 2>/dev/null | awk '/has address/ {print \$4; exit}'
''';
    return CommandScript(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(script.trim()),
    );
  }

  @override
  CommandScript tcpProbeScript(String host, int port, int timeoutSeconds) {
    final script =
        '''
nc -z -w $timeoutSeconds ${_sh(host)} ${_sh(port.toString())} 2>/dev/null ||
  timeout $timeoutSeconds sh -c 'echo >/dev/tcp/${_sh(host)}/${_sh(port.toString())}' 2>/dev/null
''';
    return CommandScript(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(script.trim()),
    );
  }

  @override
  CommandScript downloadScript({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    required Map<String, String> headers,
    required bool resume,
  }) {
    final hashCommand = _hashCommand(checksumAlgorithm);
    final tempPath =
        '$destinationPath.configr-download-${DateTime.now().microsecondsSinceEpoch}.tmp';
    final headerArgs = _curlHeaderArgs(headers);
    final continueArg = resume ? '-C - ' : '';
    final resumeFlag = resume ? '1' : '0';
    final script =
        '''
set -eu
url=${_sh(url)}
dest=${_sh(destinationPath)}
tmp=${_sh(tempPath)}
mkdir -p "\$(dirname "\$dest")"
if [ $resumeFlag -eq 1 ] && [ -f "\$dest" ]; then
  cp "\$dest" "\$tmp"
fi
total=\$(curl -fsIL -m 30 $headerArgs "\$url" 2>/dev/null | awk 'tolower(\$1)=="content-length:" {gsub("\\r","",\$2); print \$2}' | tail -n 1 || true)
(curl -fL $continueArg $headerArgs --output "\$tmp" "\$url") &
pid=\$!
while kill -0 "\$pid" 2>/dev/null; do
  size=\$(wc -c < "\$tmp" 2>/dev/null || echo 0)
  printf '{"bytes":%s,"total":%s}\\n' "\$size" "\${total:-0}"
  sleep 1
done
wait "\$pid"
mv "\$tmp" "\$dest"
size=\$(wc -c < "\$dest" 2>/dev/null || echo 0)
checksum=\$($hashCommand "\$dest" | awk '{print \$1}')
printf '{"complete":true,"bytes":%s,"checksum":"%s"}\\n' "\$size" "\$checksum"
''';
    return CommandScript(ShellType.sh.defaultExecutable, ['-s'], script);
  }

  @override
  CommandScript pingProbeScript(String host, int timeoutSeconds) {
    return CommandScript(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(
        'ping -c 1 -W ${_sh(timeoutSeconds.toString())} ${_sh(host)}',
      ),
    );
  }

  @override
  CommandScript capabilityDetectionScript() {
    final script = '''
for cmd in curl getent host md5sum nc nslookup openssl ping sha1sum sha256sum timeout; do
  if command -v "\$cmd" >/dev/null 2>&1; then echo "\$cmd:yes"; else echo "\$cmd:no"; fi
done
''';
    return CommandScript(
      ShellType.sh.defaultExecutable,
      ShellType.sh.scriptArgs(script.trim()),
    );
  }

  static String _hashCommand(String algorithm) {
    return switch (algorithm.toLowerCase()) {
      'md5' => 'md5sum',
      'sha1' => 'sha1sum',
      'sha256' => 'sha256sum',
      _ => 'sha256sum',
    };
  }
}

/// Windows implementation using PowerShell cmdlets.
class WindowsNetworkStrategy extends NetworkStrategy {
  const WindowsNetworkStrategy();

  static String _psEscape(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }

  @override
  CommandScript httpRequestScript(NetworkRequest request) {
    final method = request.method.toUpperCase();
    final uri = _psEscape(request.uri.toString());
    final body = request.body.isEmpty
        ? ''
        : ' -Body ${_psEscape(request.body)}';
    final headers = request.headers.entries
        .map((e) => '@{${_psEscape(e.key)}=${_psEscape(e.value)}}')
        .join('; ');
    final headerArg = headers.isEmpty ? '' : '-Headers @{$headers}';
    final certArg = request.validateCertificates ? '' : '-SkipCertificateCheck';
    final timeoutArg = '-TimeoutSec ${request.timeoutSeconds}';

    // Build a single-line PowerShell script using string concatenation
    // (single-quoted strings keep $ literal for PowerShell variables).
    final script = StringBuffer()
      ..write('\$ProgressPreference = "SilentlyContinue"; ')
      ..write('\$r = Invoke-WebRequest')
      ..write(' -Uri $uri')
      ..write(' -Method $method')
      ..write(body)
      ..write(' $headerArg')
      ..write(' $certArg')
      ..write(' $timeoutArg')
      ..write(' -UseBasicParsing; ')
      ..write('Write-Output \$(\$r.StatusCode); ')
      ..write('Write-Output (\$r.Content)');

    return CommandScript(
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script.toString()),
    );
  }

  @override
  CommandScript dnsResolveScript(String host) {
    final script =
        '''\$r = Resolve-DnsName -Name ${_psEscape(host)} -Type A -ErrorAction SilentlyContinue | Select-Object -First 1; if (\$r) { Write-Output \$r.IPAddress }''';
    return CommandScript(
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }

  @override
  CommandScript tcpProbeScript(String host, int port, int timeoutSeconds) {
    final script =
        '''\$r = Test-NetConnection -ComputerName ${_psEscape(host)} -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet; if (\$r) { exit 0 } else { exit 1 }''';
    return CommandScript(
      ShellType.powershell.defaultExecutable,
      ShellType.powershell.scriptArgs(script),
    );
  }

  @override
  CommandScript downloadScript({
    required String url,
    required String destinationPath,
    required String checksumAlgorithm,
    required Map<String, String> headers,
    required bool resume,
  }) {
    final uri = _psEscape(url);
    final dest = _psEscape(destinationPath);
    final headerEntries = headers.entries
        .map((e) => '@{${_psEscape(e.key)}=${_psEscape(e.value)}}')
        .join('; ');
    final headerArg = headerEntries.isEmpty ? '' : '-Headers @{$headerEntries}';
    final resumeFlag = resume ? '1' : '0';

    // PowerShell script with progress JSON written to stdout
    final script =
        '''
#Requires -Version 5.1
param()
\$ProgressPreference = 'SilentlyContinue'
if (Test-Path '$dest') {
  if ($resumeFlag -eq 1) {
    \$wc = New-Object System.Net.WebClient
    try {
      \$wc.Headers.Add('user-agent', 'configr/1.0')
      ${headers.entries.map((e) => "\$wc.Headers.Add('${e.key.replaceAll("'", "''")}','${e.value.replaceAll("'", "''")}')").join('\n      ')}
      \$wc.DownloadFile('$uri', '$dest')
      \$hash = (Get-FileHash '$dest' -Algorithm ${checksumAlgorithm.toUpperCase()}).Hash.ToLower()
      Write-Output "{`"complete`":true,`"bytes`":\$(\$wc.ResponseHeaders['Content-Length']),`"checksum`":`"\$hash`"}"
    } finally {
      \$wc.Dispose()
    }
  }
} else {
  try {
    \$r = Invoke-WebRequest -Uri $uri -OutFile '$dest' $headerArg -PassThru -UseBasicParsing
    \$hash = (Get-FileHash '$dest' -Algorithm ${checksumAlgorithm.toUpperCase()}).Hash.ToLower()
    Write-Output "{`"complete`":true,`"bytes`":\$(\$r.RawContentLength),`"checksum`":`"\$hash`"}"
  } catch {
    exit 1
  }
}
''';
    return CommandScript(
      ShellType.powershell.defaultExecutable,
      ShellType.powershellStdinCommand(),
      script,
    );
  }

  @override
  CommandScript pingProbeScript(String host, int timeoutSeconds) {
    return CommandScript('ping', [
      '-n',
      '1',
      '-w',
      (timeoutSeconds * 1000).toString(),
      host,
    ]);
  }

  @override
  CommandScript capabilityDetectionScript() {
    // PowerShell equivalent: check for common network tools
    final script = '''
Write-Output "curl:no"
\$hasGetent = Get-Command getent -ErrorAction SilentlyContinue
if (\$hasGetent) { Write-Output "getent:yes" } else { Write-Output "getent:no" }
Write-Output "host:no"
\$hasMd5 = Get-Command md5sum -ErrorAction SilentlyContinue
if (\$hasMd5) { Write-Output "md5sum:yes" } else {
  \$hasCertUtil = Get-Command certutil -ErrorAction SilentlyContinue
  if (\$hasCertUtil) { Write-Output "md5sum:yes" } else { Write-Output "md5sum:no" }
}
Write-Output "nc:no"
\$hasNslookup = Get-Command nslookup -ErrorAction SilentlyContinue
if (\$hasNslookup) { Write-Output "nslookup:yes" } else { Write-Output "nslookup:no" }
\$hasOpenssl = Get-Command openssl -ErrorAction SilentlyContinue
if (\$hasOpenssl) { Write-Output "openssl:yes" } else { Write-Output "openssl:no" }
Write-Output "ping:yes"
Write-Output "sha1sum:no"
\$hasSha256 = Get-Command sha256sum -ErrorAction SilentlyContinue
if (\$hasSha256) { Write-Output "sha256sum:yes" } else { Write-Output "sha256sum:no" }
Write-Output "timeout:no"
''';
    return CommandScript(
      ShellType.powershell.defaultExecutable,
      ShellType.powershellStdinCommand(),
      script,
    );
  }
}
