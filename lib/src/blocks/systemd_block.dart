import 'dart:io';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/platform.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:path/path.dart' as path;

/// Block handler for the `systemd` config action.
///
/// Manages systemd services: enable, disable, start, stop, restart, reload,
/// and create/edit service unit files.
///
/// ```i3
/// systemd {
///   source = "my-service"
///   operation = "enable"           # enable | disable | start | stop | restart | reload | create
///   service_type = "service"       # service | timer | socket | path | mount
///   user_service = false
///   overwrite = true
///   validate_unit = true
///   # For create operation:
///   description = "My Service"
///   exec_start = "/usr/bin/my-service"
///   exec_stop = "/usr/bin/my-service --stop"
///   restart_policy = "always"
///   wanted_by = "multi-user.target"
/// }
/// ```
class SystemdBlock extends ActionBlock {
  @override
  String get blockType => 'systemd';

  // ---------------------------------------------------------------------------
  // Systemd-specific properties
  // ---------------------------------------------------------------------------

  String operation = 'enable';
  String serviceType = 'service';
  bool isUserService = false;
  bool overwrite = true;
  bool validateUnit = true;
  String? serviceName;

  // Service unit properties (for create/edit)
  String? description;
  String? execStart;
  String? execStartPre;
  String? execStartPost;
  String? execStop;
  String? execStopPost;
  String? execReload;
  String? user;
  String? group;
  String? workingDirectory;
  Map<String, String> environment = {};
  String? restartPolicy;
  String? restartSec;
  String? serviceTypeSetting;
  bool? remainAfterExit;
  String? killMode;
  String? killSignal;
  String? timeoutStartSec;
  String? timeoutStopSec;
  String? enabled;
  String? wantedBy;
  List<String> dependencies = [];
  List<String> wants = [];
  List<String> requires = [];
  List<String> after = [];
  List<String> before = [];
  bool? privateTmp;
  bool? noNewPrivileges;
  String? protectSystem;
  String? protectHome;
  String? standardOutput;
  String? standardError;

  // Only set when require_privilege_escalation is true — tells the runner
  // to elevate before running systemctl commands.
  bool requirePrivilegeEscalation = false;

  // Paths for ReadWritePaths/ReadOnlyPaths directives
  List<String> readWritePaths = [];
  List<String> readOnlyPaths = [];

  // ---------------------------------------------------------------------------
  // Execution state
  // ---------------------------------------------------------------------------

  String? previousContent;
  String? serviceFilePath;
  bool operationSuccess = false;

  SystemdBlock();

  // ---------------------------------------------------------------------------
  // Handler pipeline
  // ---------------------------------------------------------------------------

  @override
  Map<String, String> get additionalProperties => {
    if (operation != 'enable') 'operation': operation,
    if (serviceType != 'service') 'service_type': serviceType,
    'description': ?description,
    'exec_start': ?execStart,
    'exec_start_pre': ?execStartPre,
    'exec_stop': ?execStop,
    'exec_reload': ?execReload,
    'restart_policy': ?restartPolicy,
    'wanted_by': ?wantedBy,
    if (environment.isNotEmpty)
      'environment': environment.entries
          .map((e) => '${e.key}=${e.value}')
          .join(','),
    if (dependencies.isNotEmpty) 'dependencies': dependencies.join(', '),
    if (readWritePaths.isNotEmpty)
      'read_write_paths': readWritePaths.join(', '),
    if (readOnlyPaths.isNotEmpty) 'read_only_paths': readOnlyPaths.join(', '),
  };

  @override
  Map<String, bool> get additionalBoolProperties => {
    if (isUserService) 'user_service': isUserService,
    if (!overwrite) 'overwrite': overwrite,
    if (!validateUnit) 'validate_unit': validateUnit,
    if (requirePrivilegeEscalation)
      'require_privilege_escalation': requirePrivilegeEscalation,
  };

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);

    operation = (context.getVariable('operation') as String?) ?? operation;
    serviceType = (context.getVariable('service_type') as String?) ?? 'service';
    isUserService = switch (context.getVariable('user_service')) {
      true || 'true' => true,
      _ => false,
    };
    overwrite = switch (context.getVariable('overwrite')) {
      false || 'false' => false,
      _ => true,
    };
    validateUnit = switch (context.getVariable('validate_unit')) {
      false || 'false' => false,
      _ => true,
    };

    // source is the service name
    serviceName = source.isNotEmpty ? source : null;

    // Fallback: if source was not set but a 'service' command-style property
    // was used (e.g. `service "myapp"`), read from context.
    if (serviceName == null) {
      final serviceVar = context.getVariable('service') as String?;
      if (serviceVar != null && serviceVar.isNotEmpty) {
        serviceName = serviceVar;
      }
    }

    // Service unit properties
    description = context.getVariable('description') as String?;
    execStart = context.getVariable('exec_start') as String?;
    execStop = context.getVariable('exec_stop') as String?;
    execReload = context.getVariable('exec_reload') as String?;
    restartPolicy = context.getVariable('restart_policy') as String?;
    restartSec = context.getVariable('restart_sec') as String?;
    serviceTypeSetting = context.getVariable('type') as String?;
    wantedBy = context.getVariable('wanted_by') as String?;
    user = context.getVariable('user') as String?;
    group = context.getVariable('group') as String?;
    workingDirectory = context.getVariable('working_directory') as String?;
    timeoutStartSec = context.getVariable('timeout_start_sec') as String?;
    timeoutStopSec = context.getVariable('timeout_stop_sec') as String?;

    privateTmp = switch (context.getVariable('private_tmp')) {
      true || 'true' => true,
      false || 'false' => false,
      _ => null,
    };

    noNewPrivileges = switch (context.getVariable('no_new_privileges')) {
      true || 'true' => true,
      false || 'false' => false,
      _ => null,
    };

    protectSystem = context.getVariable('protect_system') as String?;
    protectHome = context.getVariable('protect_home') as String?;

    // -- Gaps filled: properties that were declared but never populated --

    enabled = context.getVariable('enabled') as String?;

    requirePrivilegeEscalation = switch (context.getVariable(
      'require_privilege_escalation',
    )) {
      true || 'true' => true,
      _ => false,
    };

    // environment is a comma-separated list of KEY=VALUE pairs
    final envVal = context.getVariable('environment');
    if (envVal is String && envVal.isNotEmpty) {
      environment = {
        for (final pair
            in envVal
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.contains('=')))
          pair.split('=').first.trim(): pair
              .split('=')
              .sublist(1)
              .join('=')
              .trim(),
      };
    } else if (envVal is Map) {
      environment = envVal.cast<String, String>();
    }

    // Dependencies — comma-separated list
    final depsVal = context.getVariable('dependencies');
    if (depsVal is String && depsVal.isNotEmpty) {
      dependencies = depsVal.split(',').map((s) => s.trim()).toList();
    } else if (depsVal is List) {
      dependencies = depsVal.cast<String>();
    }

    // read_write_paths / read_only_paths — comma-separated
    final rwVal = context.getVariable('read_write_paths');
    if (rwVal is String && rwVal.isNotEmpty) {
      readWritePaths = rwVal.split(',').map((s) => s.trim()).toList();
    } else if (rwVal is List) {
      readWritePaths = rwVal.cast<String>();
    }

    final roVal = context.getVariable('read_only_paths');
    if (roVal is String && roVal.isNotEmpty) {
      readOnlyPaths = roVal.split(',').map((s) => s.trim()).toList();
    } else if (roVal is List) {
      readOnlyPaths = roVal.cast<String>();
    }
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  @override
  Future<void> execute() async {
    if (serviceName == null || serviceName!.isEmpty) {
      throw ActionFailedException(
        'Service name is required for systemd operations',
        moduleId: id,
      );
    }

    OsFacts.detect().requireLinux('systemd');

    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Starting systemd $operation for $serviceName',
      ),
    );

    try {
      switch (operation) {
        case 'enable':
          await _runSystemctl('enable');
          break;
        case 'disable':
          await _runSystemctl('disable');
          break;
        case 'start':
          await _runSystemctl('start');
          break;
        case 'stop':
          await _runSystemctl('stop');
          break;
        case 'restart':
          await _runSystemctl('restart');
          break;
        case 'reload':
          await _runSystemctl('reload');
          break;
        case 'create':
          await _executeCreate();
          break;
        case 'edit':
          await _executeEdit();
          break;
        case 'remove':
          await _executeRemove();
          break;
        default:
          throw ActionFailedException(
            'Unknown systemd operation: $operation',
            moduleId: id,
          );
      }

      operationSuccess = true;
      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Systemd $operation completed for $serviceName',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(
          moduleId: id,
          message: 'Systemd $operation failed for $serviceName: $e',
        ),
      );
      throw ActionFailedException(
        'Systemd $operation failed for $serviceName',
        cause: e,
        moduleId: id,
      );
    }

    status = 'completed';
  }

  @override
  Future<void> rollback() async {
    emitEvent(
      StartedEvent(
        moduleId: id,
        message: 'Rolling back systemd $operation for $serviceName',
      ),
    );

    try {
      switch (operation) {
        case 'enable':
          await _runSystemctl('disable');
          break;
        case 'disable':
          await _runSystemctl('enable');
          break;
        case 'start':
          await _runSystemctl('stop');
          break;
        case 'stop':
          await _runSystemctl('start');
          break;
        case 'create':
          await _rollbackCreate();
          break;
        case 'edit':
          await _rollbackEdit();
          break;
        case 'remove':
          await _rollbackRemove();
          break;
      }

      for (final child in children) {
        await child.rollback();
      }

      emitEvent(
        CompletedEvent(
          moduleId: id,
          message: 'Systemd rollback completed for $serviceName',
        ),
      );
    } catch (e, _) {
      emitEvent(
        FailedEvent(
          moduleId: id,
          message: 'Systemd rollback failed for $serviceName: $e',
        ),
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Systemctl execution
  // ---------------------------------------------------------------------------

  Future<void> _runSystemctl(String command) async {
    final prefix = isUserService ? '--user' : '';
    final args = [
      if (prefix.isNotEmpty) prefix,
      command,
      '$serviceName.$serviceType',
    ].where((s) => s.isNotEmpty).toList();

    final result = await Process.run('systemctl', args);

    if (result.exitCode != 0) {
      throw ActionFailedException(
        'systemctl $command failed: ${result.stderr}',
        moduleId: id,
      );
    }

    emitEvent(
      StatusUpdateEvent(
        moduleId: id,
        level: StatusEvent.info,
        message: 'systemctl $command: $serviceName',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Service file management
  // ---------------------------------------------------------------------------

  String _getServiceFilePath() {
    final dir = isUserService
        ? '${Platform.environment['HOME'] ?? '/root'}/.config/systemd/user'
        : '/etc/systemd/system';
    return '$dir/$serviceName.$serviceType';
  }

  Future<void> _captureExistingContent() async {
    serviceFilePath = _getServiceFilePath();
    if (await fileService.fileExists(serviceFilePath!)) {
      previousContent = await fileService.readFile(
        serviceFilePath!,

      );
    }
  }

  Future<void> _executeCreate() async {
    await _captureExistingContent();

    if (previousContent != null && !overwrite) {
      throw ActionFailedException(
        'Service file already exists at $serviceFilePath and overwrite is false',
        moduleId: id,
      );
    }

    final content = _generateServiceContent();

    // Validate unit file if requested
    if (validateUnit) {
      await _validateServiceFile(content);
    }

    // Ensure directory exists
    final dir = path.dirname(serviceFilePath!);
    if (!await fileService.directoryExists(dir)) {
      await fileService.createDirectory(dir);
    }

    await fileService.writeFile(
      serviceFilePath!,
      content,

    );

    // Reload systemd daemon
    await _runSystemctl('daemon-reload');

    if (enabled == 'true') {
      await _runSystemctl('enable');
    }
  }

  Future<void> _executeEdit() async {
    await _captureExistingContent();
    if (previousContent == null) {
      throw ActionFailedException(
        'Service file does not exist at $serviceFilePath',
        moduleId: id,
      );
    }

    final content = _generateServiceContent();

    if (validateUnit) {
      await _validateServiceFile(content);
    }

    await fileService.writeFile(
      serviceFilePath!,
      content,

    );
    await _runSystemctl('daemon-reload');
  }

  Future<void> _executeRemove() async {
    serviceFilePath = _getServiceFilePath();
    await _captureExistingContent();

    if (previousContent == null) {
      logger.info('Service file does not exist, nothing to remove');
      return;
    }

    // Stop and disable service first
    try {
      await _runSystemctl('stop');
    } catch (_) {}
    try {
      await _runSystemctl('disable');
    } catch (_) {}

    await fileService.deleteFile(serviceFilePath!);
    await _runSystemctl('daemon-reload');
  }

  Future<void> _rollbackCreate() async {
    if (previousContent != null) {
      // Restore previous content
      await fileService.writeFile(
        serviceFilePath!,
        previousContent!,

      );
    } else if (serviceFilePath != null &&
        await fileService.fileExists(serviceFilePath!)) {
      await fileService.deleteFile(serviceFilePath!);
    }
  }

  Future<void> _rollbackEdit() async {
    if (previousContent != null) {
      await fileService.writeFile(
        serviceFilePath!,
        previousContent!,

      );
      await _runSystemctl('daemon-reload');
    }
  }

  Future<void> _rollbackRemove() async {
    if (previousContent != null) {
      // Ensure directory exists
      final dir = path.dirname(serviceFilePath!);
      if (!await fileService.directoryExists(dir)) {
        await fileService.createDirectory(dir);
      }
      await fileService.writeFile(
        serviceFilePath!,
        previousContent!,

      );
      await _runSystemctl('daemon-reload');
    }
  }

  String _generateServiceContent() {
    final buffer = StringBuffer();

    // [Unit] section
    buffer.writeln('[Unit]');
    buffer.writeln('Description=$description');
    if (wants.isNotEmpty) buffer.writeln('Wants=${wants.join(' ')}');
    if (requires.isNotEmpty) buffer.writeln('Requires=${requires.join(' ')}');
    if (after.isNotEmpty) buffer.writeln('After=${after.join(' ')}');
    if (before.isNotEmpty) buffer.writeln('Before=${before.join(' ')}');
    buffer.writeln();

    // [Service] section
    buffer.writeln('[Service]');
    if (execStart != null) buffer.writeln('ExecStart=$execStart');
    if (execStartPre != null) buffer.writeln('ExecStartPre=$execStartPre');
    if (execStartPost != null) buffer.writeln('ExecStartPost=$execStartPost');
    if (execStop != null) buffer.writeln('ExecStop=$execStop');
    if (execStopPost != null) buffer.writeln('ExecStopPost=$execStopPost');
    if (execReload != null) buffer.writeln('ExecReload=$execReload');
    if (serviceTypeSetting != null) buffer.writeln('Type=$serviceTypeSetting');
    if (restartPolicy != null) buffer.writeln('Restart=$restartPolicy');
    if (restartSec != null) buffer.writeln('RestartSec=$restartSec');
    if (user != null) buffer.writeln('User=$user');
    if (group != null) buffer.writeln('Group=$group');
    if (workingDirectory != null) {
      buffer.writeln('WorkingDirectory=$workingDirectory');
    }
    if (timeoutStartSec != null) {
      buffer.writeln('TimeoutStartSec=$timeoutStartSec');
    }
    if (timeoutStopSec != null) {
      buffer.writeln('TimeoutStopSec=$timeoutStopSec');
    }
    if (killMode != null) buffer.writeln('KillMode=$killMode');
    if (killSignal != null) buffer.writeln('KillSignal=$killSignal');
    if (remainAfterExit == true) buffer.writeln('RemainAfterExit=true');
    if (environment.isNotEmpty) {
      for (final entry in environment.entries) {
        buffer.writeln('Environment=${entry.key}=${entry.value}');
      }
    }
    if (standardOutput != null) {
      buffer.writeln('StandardOutput=$standardOutput');
    }
    if (standardError != null) {
      buffer.writeln('StandardError=$standardError');
    }
    if (privateTmp == true) buffer.writeln('PrivateTmp=true');
    if (noNewPrivileges == true) buffer.writeln('NoNewPrivileges=true');
    if (protectSystem != null) buffer.writeln('ProtectSystem=$protectSystem');
    if (protectHome != null) buffer.writeln('ProtectHome=$protectHome');
    if (readWritePaths.isNotEmpty) {
      buffer.writeln('ReadWritePaths=${readWritePaths.join(' ')}');
    }
    if (readOnlyPaths.isNotEmpty) {
      buffer.writeln('ReadOnlyPaths=${readOnlyPaths.join(' ')}');
    }
    buffer.writeln();

    // [Install] section
    buffer.writeln('[Install]');
    if (wantedBy != null) buffer.writeln('WantedBy=$wantedBy');
    if (enabled != null && enabled == 'true') {
      buffer.writeln('WantedBy=${wantedBy ?? 'multi-user.target'}');
    }

    return buffer.toString();
  }

  Future<void> _validateServiceFile(String content) async {
    // Write to temp file for validation
    final tempDir = Directory.systemTemp.createTempSync('systemd_');
    final tempFile = File('${tempDir.path}/$serviceName.$serviceType');
    try {
      await tempFile.writeAsString(content);

      final result = await Process.run('systemd-analyze', [
        'verify',
        tempFile.path,
      ]);

      if (result.exitCode != 0) {
        throw ActionFailedException(
          'Service unit validation failed: ${result.stderr}',
          moduleId: id,
        );
      }
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }
}
