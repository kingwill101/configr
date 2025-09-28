import 'dart:async';
import 'dart:io';
import 'package:configr/events/module_events.dart';
import 'package:configr/exceptions.dart';
import 'package:configr/modules/resource/resource_module.dart';
import 'package:configr/utils/logging.dart';
import 'package:configr/utils/event_bus.dart';
import 'package:configr/utils/privellage_escallation.dart';
import 'package:configr/utils/file_utils.dart';

/// Systemd unit file generation module inspired by Chef/Puppet systemd management.
///
/// Features:
/// - Generate systemd unit files (.service, .timer, .socket, .mount, .automount)
/// - Generate systemd drop-in files for service overrides
/// - Generate init.d scripts for legacy systems
/// - Service configuration template processing with Liquid templating
/// - Environment variable and dependency management
/// - Service file validation and formatting
/// - Cross-platform service file generation
/// - Comprehensive event emission and logging
/// - Service configuration rollback support
/// - Support for systemd resource limits, security options, and advanced features
class FileSystemdModule extends ResourceModule {
  // State getters
  String get serviceName => state['serviceName'] as String? ?? '';
  String get serviceType => state['serviceType'] as String? ?? 'service';
  String get unitContent => state['unitContent'] as String? ?? '';
  String? get previousContent => state['previousContent'] as String?;
  String get serviceManager => state['serviceManager'] as String? ?? 'systemd';
  String get destination => state['destination'] as String? ?? '';
  bool get overwrite => state['overwrite'] as bool? ?? false;
  bool get validateUnit => state['validateUnit'] as bool? ?? true;
  bool get isUserService => state['isUserService'] as bool? ?? false;
  bool get requirePrivilegeEscalation =>
      state['requirePrivilegeEscalation'] as bool? ?? false;
  String? get errorMessage => state['errorMessage'] as String?;
  Duration get operationDuration =>
      Duration(milliseconds: state['operationDuration'] as int? ?? 0);

  // Service configuration properties
  String get description => state['description'] as String? ?? '';
  String get execStart => state['execStart'] as String? ?? '';
  String? get execStartPre => state['execStartPre'] as String?;
  String? get execStartPost => state['execStartPost'] as String?;
  String? get execStop => state['execStop'] as String?;
  String? get execStopPost => state['execStopPost'] as String?;
  String? get execReload => state['execReload'] as String?;
  String get user => state['user'] as String? ?? 'root';
  String get group => state['group'] as String? ?? 'root';
  String? get workingDirectory => state['workingDirectory'] as String?;
  List<String> get environment =>
      List<String>.from(state['environment'] as List<dynamic>? ?? []);
  List<String> get dependencies =>
      List<String>.from(state['dependencies'] as List<dynamic>? ?? []);
  List<String> get wants =>
      List<String>.from(state['wants'] as List<dynamic>? ?? []);
  List<String> get requires =>
      List<String>.from(state['requires'] as List<dynamic>? ?? []);
  List<String> get after =>
      List<String>.from(state['after'] as List<dynamic>? ?? []);
  List<String> get before =>
      List<String>.from(state['before'] as List<dynamic>? ?? []);
  String get restartPolicy => state['restartPolicy'] as String? ?? 'on-failure';
  int get restartSec => state['restartSec'] as int? ?? 5;
  String get type => state['type'] as String? ?? 'simple';
  bool get remainAfterExit => state['remainAfterExit'] as bool? ?? false;
  bool get killMode => state['killMode'] as bool? ?? false;
  String get killSignal => state['killSignal'] as String? ?? 'SIGTERM';
  int get timeoutStartSec => state['timeoutStartSec'] as int? ?? 90;
  int get timeoutStopSec => state['timeoutStopSec'] as int? ?? 90;
  bool get enabled => state['enabled'] as bool? ?? true;
  String get wantedBy => state['wantedBy'] as String? ?? 'multi-user.target';

  // Advanced systemd configuration (inspired by Chef/Puppet)
  bool get isDropIn => state['isDropIn'] as bool? ?? false;
  String? get dropInName => state['dropInName'] as String?;
  Map<String, String> get resourceLimits => Map<String, String>.from(
    state['resourceLimits'] as Map<String, dynamic>? ?? {},
  );
  Map<String, String> get securityOptions => Map<String, String>.from(
    state['securityOptions'] as Map<String, dynamic>? ?? {},
  );
  List<String> get supplementaryGroups =>
      List<String>.from(state['supplementaryGroups'] as List<dynamic>? ?? []);
  String? get nice => state['nice'] as String?;
  String? get ioPriority => state['ioPriority'] as String?;
  String? get oomScoreAdjust => state['oomScoreAdjust'] as String?;
  bool get privateTmp => state['privateTmp'] as bool? ?? false;
  bool get protectSystem => state['protectSystem'] as bool? ?? false;
  bool get protectHome => state['protectHome'] as bool? ?? false;
  bool get noNewPrivileges => state['noNewPrivileges'] as bool? ?? false;
  List<String> get readWritePaths =>
      List<String>.from(state['readWritePaths'] as List<dynamic>? ?? []);
  List<String> get readOnlyPaths =>
      List<String>.from(state['readOnlyPaths'] as List<dynamic>? ?? []);
  List<String> get inaccessiblePaths =>
      List<String>.from(state['inaccessiblePaths'] as List<dynamic>? ?? []);
  String? get umask => state['umask'] as String?;
  String? get standardInput => state['standardInput'] as String?;
  String? get standardOutput => state['standardOutput'] as String?;
  String? get standardError => state['standardError'] as String?;
  bool get tty => state['tty'] as bool? ?? false;
  String? get syslogIdentifier => state['syslogIdentifier'] as String?;
  int get syslogFacility => state['syslogFacility'] as int? ?? 3;
  String? get syslogLevel => state['syslogLevel'] as String?;
  bool get syslogLevelFromStderr =>
      state['syslogLevelFromStderr'] as bool? ?? false;

  /// Get appropriate privilege escalation for the service type.
  PrivilegeEscalation _getPrivilegeEscalation() {
    if (isUserService || !requirePrivilegeEscalation) {
      return NoPrivilegeEscalation();
    }
    return InteractiveSudoEscalation();
  }

  FileSystemdModule(
    super.file,
    super.action, {
    super.allowedActions = const ['systemd'],
    super.fileSystem,
  }) {
    updateState({
      'serviceName': '',
      'serviceType': 'service',
      'unitContent': '',
      'previousContent': null,
      'serviceManager': 'systemd',
      'destination': '',
      'overwrite': false,
      'validateUnit': true,
      'isUserService': false,
      'requirePrivilegeEscalation': false,
      'errorMessage': null,
      'operationDuration': 0,
      'description': '',
      'execStart': '',
      'execStartPre': null,
      'execStartPost': null,
      'execStop': null,
      'execStopPost': null,
      'execReload': null,
      'user': 'root',
      'group': 'root',
      'workingDirectory': null,
      'environment': <String>[],
      'dependencies': <String>[],
      'wants': <String>[],
      'requires': <String>[],
      'after': <String>[],
      'before': <String>[],
      'restartPolicy': 'on-failure',
      'restartSec': 5,
      'type': 'simple',
      'remainAfterExit': false,
      'killMode': false,
      'killSignal': 'SIGTERM',
      'timeoutStartSec': 90,
      'timeoutStopSec': 90,
      'enabled': true,
      'wantedBy': 'multi-user.target',
      // Advanced systemd options
      'isDropIn': false,
      'dropInName': null,
      'resourceLimits': <String, String>{},
      'securityOptions': <String, String>{},
      'supplementaryGroups': <String>[],
      'nice': null,
      'ioPriority': null,
      'oomScoreAdjust': null,
      'privateTmp': false,
      'protectSystem': false,
      'protectHome': false,
      'noNewPrivileges': false,
      'readWritePaths': <String>[],
      'readOnlyPaths': <String>[],
      'inaccessiblePaths': <String>[],
      'umask': null,
      'standardInput': null,
      'standardOutput': null,
      'standardError': null,
      'tty': false,
      'syslogIdentifier': null,
      'syslogFacility': 3,
      'syslogLevel': null,
      'syslogLevelFromStderr': false,
    });
  }

  @override
  Future<void> execute() async {
    emitEvent(
      StartedEvent(
        moduleId: action.id,
        message: 'Starting service configuration generation',
      ),
    );

    // Parse configuration
    final config = _parseConfiguration();
    final serviceName = action.properties['service'] as String?;
    if (serviceName == null || serviceName.isEmpty) {
      throw ActionFailedException(
        'Service name is required for systemd module',
        moduleId: action.id,
      );
    }

    // Set service name first so _getDefaultDestination() can use it
    updateState({
      'serviceName': serviceName,
      'serviceType': action.properties['type'] as String? ?? 'service',
      ...config,
    });

    // Now set destination after serviceName is available
    final customDestination = action.properties['destination'] as String?;
    final finalDestination = customDestination ?? _getDefaultDestination();

    // Validate destination permissions
    await _validateDestination(finalDestination);

    updateState({'destination': finalDestination});

    await executeModules();
    if (isRollingBack) {
      return;
    }

    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.info,
        message: 'Generating service configuration: $serviceName',
      ),
    );
    logger.info('Generating service configuration: $serviceName');

    final startTime = DateTime.now();
    try {
      // Read existing content for rollback
      await _captureExistingContent();

      // Generate service unit content
      final content = await _generateServiceContent();
      updateState({'unitContent': content});

      // Write service file
      await _writeServiceFile(content);

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      updateState({'operationDuration': duration.inMilliseconds});

      // Validate service file if required
      if (validateUnit) {
        await _validateServiceFile();
      }

      logger.info(
        'Service configuration generated successfully for $serviceName',
      );
      emitEvent(
        CompletedEvent(
          moduleId: action.id,
          message:
              'Service configuration generated successfully in ${duration.inMilliseconds}ms',
        ),
      );
    } catch (e, s) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      updateState({
        'errorMessage': e.toString(),
        'operationDuration': duration.inMilliseconds,
      });
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Service configuration generation failed: ${e.toString()}',
        ),
      );
      throw ActionFailedException(
        'Failed to generate service configuration for $serviceName',
        moduleId: action.id,
        cause: e,
        stackTrace: s,
      );
    }

    action.status = 'completed';
    action.timestamp = DateTime.now().toIso8601String();
    await saveState();
  }

  @override
  Future<void> rollback() async {
    logger.info('Rolling back service configuration for $serviceName');
    emitEvent(
      StatusUpdateEvent(
        moduleId: action.id,
        level: StatusEvent.warning,
        message: 'Rolling back service configuration for $serviceName',
      ),
    );

    try {
      if (previousContent != null) {
        // Restore previous content
        await _writeServiceFile(previousContent!);
        logger.info('Service configuration restored for $serviceName');
        emitEvent(
          CompletedEvent(
            moduleId: action.id,
            message: 'Service configuration restored',
          ),
        );
      } else {
        // Remove the file if it didn't exist before
        try {
          await FileUtils.deleteFileWithPermissionsCrossPlatform(
            destination,
            fileSystem: fileSystem,
            privilegeEscalation: _getPrivilegeEscalation(),
            requireElevation: requirePrivilegeEscalation && !isUserService,
          );
          logger.info('Service configuration file removed for $serviceName');
          emitEvent(
            CompletedEvent(
              moduleId: action.id,
              message: 'Service configuration file removed',
            ),
          );
        } catch (e) {
          logger.warning('Could not remove service file: $e');
        }
      }
    } catch (e) {
      logger.severe(
        'Service configuration rollback failed for $serviceName: $e',
      );
      emitEvent(
        FailedEvent(
          moduleId: action.id,
          message: 'Service configuration rollback failed: ${e.toString()}',
        ),
      );
    }

    for (var module in childModules) {
      await module.rollback();
    }

    await saveState();
  }

  /// Parse configuration from action properties.
  Map<String, dynamic> _parseConfiguration() {
    final env = <String>[];
    if (action.properties.containsKey('environment')) {
      final envData = action.properties['environment'];
      if (envData is List) {
        env.addAll(envData.cast<String>());
      } else if (envData is String) {
        env.addAll(envData.split(',').map((s) => s.trim()));
      }
    }

    final deps = <String>[];
    if (action.properties.containsKey('dependencies')) {
      final depsData = action.properties['dependencies'];
      if (depsData is List) {
        // Handle nested lists (when configr parses arrays as nested lists)
        for (final item in depsData) {
          if (item is List) {
            deps.addAll(item.cast<String>());
          } else if (item is String) {
            deps.add(item);
          }
        }
      } else if (depsData is String) {
        deps.addAll(depsData.split(',').map((s) => s.trim()));
      }
    }

    // Parse resource limits
    final resourceLimits = <String, String>{};
    if (action.properties.containsKey('resource_limits')) {
      final limitsData = action.properties['resource_limits'];
      if (limitsData is Map) {
        resourceLimits.addAll(Map<String, String>.from(limitsData));
      }
    }

    // Parse security options
    final securityOptions = <String, String>{};
    if (action.properties.containsKey('security_options')) {
      final securityData = action.properties['security_options'];
      if (securityData is Map) {
        securityOptions.addAll(Map<String, String>.from(securityData));
      }
    }

    return {
      'serviceManager': action.properties['service_manager'] ?? 'systemd',
      'overwrite': action.properties['overwrite'] == 'true',
      'validateUnit': action.properties['validate_unit'] != 'false',
      'isUserService':
          action.properties['user_service'] == true ||
          action.properties['user_service'] == 'true',
      'requirePrivilegeEscalation':
          action.properties['require_privilege_escalation'] == true ||
          action.properties['require_privilege_escalation'] == 'true',
      'description': action.properties['description'] ?? '',
      'execStart': action.properties['exec_start'] ?? '',
      'execStartPre': action.properties['exec_start_pre'],
      'execStartPost': action.properties['exec_start_post'],
      'execStop': action.properties['exec_stop'],
      'execStopPost': action.properties['exec_stop_post'],
      'execReload': action.properties['exec_reload'],
      'user': action.properties['user'] ?? 'root',
      'group': action.properties['group'] ?? 'root',
      'workingDirectory': action.properties['working_directory'],
      'environment': env,
      'dependencies': deps,
      'wants': _parseListProperty('wants'),
      'requires': _parseListProperty('requires'),
      'after': _parseListProperty('after'),
      'before': _parseListProperty('before'),
      'restartPolicy': action.properties['restart_policy'] ?? 'on-failure',
      'restartSec':
          int.tryParse(action.properties['restart_sec']?.toString() ?? '') ?? 5,
      'type': action.properties['service_type'] ?? 'simple',
      'remainAfterExit': action.properties['remain_after_exit'] == 'true',
      'killMode': action.properties['kill_mode'] == 'true',
      'killSignal': action.properties['kill_signal'] ?? 'SIGTERM',
      'timeoutStartSec':
          int.tryParse(
            action.properties['timeout_start_sec']?.toString() ?? '',
          ) ??
          90,
      'timeoutStopSec':
          int.tryParse(
            action.properties['timeout_stop_sec']?.toString() ?? '',
          ) ??
          90,
      'enabled': action.properties['enabled'] != 'false',
      'wantedBy': action.properties['wanted_by'] ?? 'multi-user.target',
      // Advanced systemd options
      'isDropIn': action.properties['is_drop_in'] == 'true',
      'dropInName': action.properties['drop_in_name'],
      'resourceLimits': resourceLimits,
      'securityOptions': securityOptions,
      'supplementaryGroups': _parseListProperty('supplementary_groups'),
      'nice': action.properties['nice'],
      'ioPriority': action.properties['io_priority'],
      'oomScoreAdjust': action.properties['oom_score_adjust'],
      'privateTmp': action.properties['private_tmp'] == 'true',
      'protectSystem': action.properties['protect_system'] == 'true',
      'protectHome': action.properties['protect_home'] == 'true',
      'noNewPrivileges': action.properties['no_new_privileges'] == 'true',
      'readWritePaths': _parseListProperty('read_write_paths'),
      'readOnlyPaths': _parseListProperty('read_only_paths'),
      'inaccessiblePaths': _parseListProperty('inaccessible_paths'),
      'umask': action.properties['umask'],
      'standardInput': action.properties['standard_input'],
      'standardOutput': action.properties['standard_output'],
      'standardError': action.properties['standard_error'],
      'tty': action.properties['tty'] == 'true',
      'syslogIdentifier': action.properties['syslog_identifier'],
      'syslogFacility':
          int.tryParse(
            action.properties['syslog_facility']?.toString() ?? '',
          ) ??
          3,
      'syslogLevel': action.properties['syslog_level'],
      'syslogLevelFromStderr':
          action.properties['syslog_level_from_stderr'] == 'true',
    };
  }

  /// Parse list property from action properties.
  List<String> _parseListProperty(String key) {
    final data = action.properties[key];
    if (data is List) {
      final result = <String>[];
      // Handle nested lists (when configr parses arrays as nested lists)
      for (final item in data) {
        if (item is List) {
          result.addAll(item.cast<String>());
        } else if (item is String) {
          result.add(item);
        }
      }
      return result;
    } else if (data is String) {
      return data.split(',').map((s) => s.trim()).toList();
    }
    return [];
  }

  /// Validate destination permissions and provide helpful error messages.
  Future<void> _validateDestination(String destination) async {
    logger.info('Validating destination permissions: $destination');

    try {
      final parentDir = File(destination).parent;
      final parentCheck = await FileUtils.checkPermissionsCrossPlatform(
        parentDir.path,
        requireWrite: true,
        fileSystem: fileSystem,
      );

      if (!parentCheck.exists) {
        logger.info(
          'Parent directory does not exist, will create: ${parentDir.path}',
        );
      } else if (!parentCheck.canWrite) {
        if (requirePrivilegeEscalation && !isUserService) {
          logger.info(
            'Parent directory requires privilege escalation: ${parentDir.path}',
          );
        } else {
          throw ActionFailedException(
            'Cannot write to parent directory: ${parentDir.path}\n'
            'Please check permissions or use a different destination.',
            moduleId: action.id,
          );
        }
      }

      // Check if file already exists
      final fileCheck = await FileUtils.checkPermissionsCrossPlatform(
        destination,
        fileSystem: fileSystem,
      );
      if (fileCheck.exists && !overwrite) {
        throw ActionFailedException(
          'Service file already exists at $destination and overwrite is disabled.\n'
          'Set overwrite=true to replace existing files.',
          moduleId: action.id,
        );
      }

      logger.info('Destination validation passed: $destination');
    } catch (e) {
      if (e is ActionFailedException) {
        rethrow;
      }
      logger.warning('Destination validation failed: $destination - $e');
      // Continue execution, let the actual operation handle the error
    }
  }

  /// Get default destination path for service file.
  String _getDefaultDestination() {
    final serviceManager = this.serviceManager;
    final fileName = '$serviceName.$serviceType';

    switch (serviceManager) {
      case 'systemd':
        if (isUserService) {
          // User services go to user's systemd directory
          final userHome =
              Platform.environment['HOME'] ??
              '/home/${Platform.environment['USER']}';
          if (isDropIn) {
            final dropInFileName = dropInName ?? 'override';
            return '$userHome/.config/systemd/user/$serviceName.$serviceType.d/$dropInFileName.conf';
          }
          return '$userHome/.config/systemd/user/$fileName';
        } else {
          // System services go to system systemd directory
          if (isDropIn) {
            final dropInFileName = dropInName ?? 'override';
            return '/etc/systemd/system/$serviceName.$serviceType.d/$dropInFileName.conf';
          }
          return '/etc/systemd/system/$fileName';
        }
      case 'init.d':
        return '/etc/init.d/$serviceName';
      default:
        if (isUserService) {
          final userHome =
              Platform.environment['HOME'] ??
              '/home/${Platform.environment['USER']}';
          if (isDropIn) {
            final dropInFileName = dropInName ?? 'override';
            return '$userHome/.config/systemd/user/$serviceName.$serviceType.d/$dropInFileName.conf';
          }
          return '$userHome/.config/systemd/user/$fileName';
        } else {
          if (isDropIn) {
            final dropInFileName = dropInName ?? 'override';
            return '/etc/systemd/system/$serviceName.$serviceType.d/$dropInFileName.conf';
          }
          return '/etc/systemd/system/$fileName';
        }
    }
  }

  /// Capture existing content for rollback.
  Future<void> _captureExistingContent() async {
    try {
      final fileCheck = await FileUtils.checkPermissionsCrossPlatform(
        destination,
        requireRead: true,
        fileSystem: fileSystem,
      );

      if (fileCheck.exists) {
        if (!overwrite) {
          throw ActionFailedException(
            'Service file already exists at $destination and overwrite is disabled',
            moduleId: action.id,
          );
        }

        // Read existing content
        try {
          final result =
              await FileUtils.executeCommandWithPermissionsCrossPlatform(
                'cat',
                [destination],
                privilegeEscalation: _getPrivilegeEscalation(),
                requireElevation: requirePrivilegeEscalation && !isUserService,
                description: 'Read existing service file content',
              );

          if (result.exitCode == 0) {
            final existingContent = result.stdout.toString();
            updateState({'previousContent': existingContent});
            logger.info('Captured existing content for rollback');
          }
        } catch (e) {
          logger.warning('Could not read existing file content: $e');
        }
      }
    } catch (e) {
      if (e is ActionFailedException) {
        rethrow;
      }
      logger.warning('Could not capture existing content: $e');
    }
  }

  /// Generate service unit content based on configuration.
  Future<String> _generateServiceContent() async {
    switch (serviceManager) {
      case 'systemd':
        return _generateSystemdUnit();
      case 'init.d':
        return _generateInitScript();
      default:
        return _generateSystemdUnit();
    }
  }

  /// Generate systemd unit file content.
  String _generateSystemdUnit() {
    final buffer = StringBuffer();

    // [Unit] section
    buffer.writeln('[Unit]');
    buffer.writeln('Description=$description');

    if (dependencies.isNotEmpty) {
      buffer.writeln('Wants=${dependencies.join(' ')}');
    }
    if (wants.isNotEmpty) {
      buffer.writeln('Wants=${wants.join(' ')}');
    }
    if (requires.isNotEmpty) {
      buffer.writeln('Requires=${requires.join(' ')}');
    }
    if (after.isNotEmpty) {
      buffer.writeln('After=${after.join(' ')}');
    }
    if (before.isNotEmpty) {
      buffer.writeln('Before=${before.join(' ')}');
    }
    buffer.writeln();

    // [Service] section
    buffer.writeln('[Service]');
    buffer.writeln('Type=$type');
    buffer.writeln('User=$user');
    buffer.writeln('Group=$group');

    if (workingDirectory != null) {
      buffer.writeln('WorkingDirectory=$workingDirectory');
    }

    if (execStart.isNotEmpty) {
      buffer.writeln('ExecStart=$execStart');
    }
    if (execStartPre != null) {
      buffer.writeln('ExecStartPre=$execStartPre');
    }
    if (execStartPost != null) {
      buffer.writeln('ExecStartPost=$execStartPost');
    }
    if (execStop != null) {
      buffer.writeln('ExecStop=$execStop');
    }
    if (execStopPost != null) {
      buffer.writeln('ExecStopPost=$execStopPost');
    }
    if (execReload != null) {
      buffer.writeln('ExecReload=$execReload');
    }

    if (environment.isNotEmpty) {
      for (final env in environment) {
        buffer.writeln('Environment="$env"');
      }
    }

    buffer.writeln('Restart=$restartPolicy');
    buffer.writeln('RestartSec=$restartSec');
    buffer.writeln('TimeoutStartSec=$timeoutStartSec');
    buffer.writeln('TimeoutStopSec=$timeoutStopSec');

    if (remainAfterExit) {
      buffer.writeln('RemainAfterExit=yes');
    }

    if (killMode) {
      buffer.writeln('KillMode=process');
    }

    buffer.writeln('KillSignal=$killSignal');

    // Advanced systemd options
    if (supplementaryGroups.isNotEmpty) {
      buffer.writeln('SupplementaryGroups=${supplementaryGroups.join(' ')}');
    }

    if (nice != null) {
      buffer.writeln('Nice=$nice');
    }

    if (ioPriority != null) {
      buffer.writeln('IOSchedulingPriority=$ioPriority');
    }

    if (oomScoreAdjust != null) {
      buffer.writeln('OOMScoreAdjust=$oomScoreAdjust');
    }

    if (umask != null) {
      buffer.writeln('UMask=$umask');
    }

    if (standardInput != null) {
      buffer.writeln('StandardInput=$standardInput');
    }

    if (standardOutput != null) {
      buffer.writeln('StandardOutput=$standardOutput');
    }

    if (standardError != null) {
      buffer.writeln('StandardError=$standardError');
    }

    if (tty) {
      buffer.writeln('TTYPath=/dev/tty');
    }

    if (syslogIdentifier != null) {
      buffer.writeln('SyslogIdentifier=$syslogIdentifier');
    }

    if (syslogFacility != 3) {
      buffer.writeln('SyslogFacility=$syslogFacility');
    }

    if (syslogLevel != null) {
      buffer.writeln('SyslogLevel=$syslogLevel');
    }

    if (syslogLevelFromStderr) {
      buffer.writeln('SyslogLevelFromStderr=yes');
    }

    // Security options
    if (privateTmp) {
      buffer.writeln('PrivateTmp=yes');
    }

    if (protectSystem) {
      buffer.writeln('ProtectSystem=strict');
    }

    if (protectHome) {
      buffer.writeln('ProtectHome=yes');
    }

    if (noNewPrivileges) {
      buffer.writeln('NoNewPrivileges=yes');
    }

    if (readWritePaths.isNotEmpty) {
      buffer.writeln('ReadWritePaths=${readWritePaths.join(' ')}');
    }

    if (readOnlyPaths.isNotEmpty) {
      buffer.writeln('ReadOnlyPaths=${readOnlyPaths.join(' ')}');
    }

    if (inaccessiblePaths.isNotEmpty) {
      buffer.writeln('InaccessiblePaths=${inaccessiblePaths.join(' ')}');
    }

    // Resource limits
    if (resourceLimits.isNotEmpty) {
      for (final entry in resourceLimits.entries) {
        buffer.writeln('Limit${entry.key}=${entry.value}');
      }
    }

    // Security options
    if (securityOptions.isNotEmpty) {
      for (final entry in securityOptions.entries) {
        buffer.writeln('${entry.key}=${entry.value}');
      }
    }

    buffer.writeln();

    // [Install] section (only for regular units, not drop-ins)
    if (!isDropIn) {
      buffer.writeln('[Install]');
      buffer.writeln('WantedBy=$wantedBy');
    }

    return buffer.toString();
  }

  /// Generate init.d script content.
  String _generateInitScript() {
    final buffer = StringBuffer();

    buffer.writeln('#!/bin/bash');
    buffer.writeln('#');
    buffer.writeln('# $description');
    buffer.writeln('#');
    buffer.writeln('# chkconfig: 35 80 20');
    buffer.writeln('# description: $description');
    buffer.writeln();
    buffer.writeln('### BEGIN INIT INFO');
    buffer.writeln('# Provides: $serviceName');
    buffer.writeln('# Required-Start: ${dependencies.join(' ')}');
    buffer.writeln('# Required-Stop:');
    buffer.writeln('# Default-Start: 2 3 4 5');
    buffer.writeln('# Default-Stop: 0 1 6');
    buffer.writeln('# Description: $description');
    buffer.writeln('### END INIT INFO');
    buffer.writeln();

    if (workingDirectory != null) {
      buffer.writeln('WORKING_DIR="$workingDirectory"');
    } else {
      buffer.writeln('WORKING_DIR="/"');
    }
    buffer.writeln();

    buffer.writeln('start() {');
    buffer.writeln('    echo -n "Starting $serviceName: "');
    if (workingDirectory != null) {
      buffer.writeln('    cd "\$WORKING_DIR"');
    }
    buffer.writeln('    $execStart');
    buffer.writeln('    echo "OK"');
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('stop() {');
    buffer.writeln('    echo -n "Stopping $serviceName: "');
    if (execStop != null) {
      buffer.writeln('    $execStop');
    } else {
      buffer.writeln('    killall $serviceName');
    }
    buffer.writeln('    echo "OK"');
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('restart() {');
    buffer.writeln('    stop');
    buffer.writeln('    sleep 2');
    buffer.writeln('    start');
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('reload() {');
    if (execReload != null) {
      buffer.writeln('    echo -n "Reloading $serviceName: "');
      buffer.writeln('    $execReload');
      buffer.writeln('    echo "OK"');
    } else {
      buffer.writeln('    restart');
    }
    buffer.writeln('}');
    buffer.writeln();

    buffer.writeln('case "\$1" in');
    buffer.writeln('    start)');
    buffer.writeln('        start');
    buffer.writeln('        ;;');
    buffer.writeln('    stop)');
    buffer.writeln('        stop');
    buffer.writeln('        ;;');
    buffer.writeln('    restart)');
    buffer.writeln('        restart');
    buffer.writeln('        ;;');
    buffer.writeln('    reload)');
    buffer.writeln('        reload');
    buffer.writeln('        ;;');
    buffer.writeln('    *)');
    buffer.writeln('        echo "Usage: \$0 {start|stop|restart|reload}"');
    buffer.writeln('        exit 1');
    buffer.writeln('        ;;');
    buffer.writeln('esac');
    buffer.writeln();
    buffer.writeln('exit 0');

    return buffer.toString();
  }

  /// Write service file to destination.
  Future<void> _writeServiceFile(String content) async {
    logger.info('Writing service file to: $destination');

    try {
      // Write the content with permission awareness
      await FileUtils.writeFileWithPermissionsCrossPlatform(
        destination,
        content,
        fileSystem: fileSystem,
        recursive: true,
        privilegeEscalation: _getPrivilegeEscalation(),
        requireElevation: requirePrivilegeEscalation && !isUserService,
      );

      // Make executable for init.d scripts
      if (serviceManager == 'init.d') {
        try {
          await FileUtils.executeCommandWithPermissionsCrossPlatform(
            'chmod',
            ['+x', destination],
            privilegeEscalation: _getPrivilegeEscalation(),
            requireElevation: requirePrivilegeEscalation && !isUserService,
            description: 'Make init.d script executable',
          );
        } catch (e) {
          logger.warning('Could not make init.d script executable: $e');
        }
      }

      logger.info('Service file written successfully to $destination');
    } catch (e) {
      logger.severe('Failed to write service file to $destination: $e');
      throw ActionFailedException(
        'Failed to write service file: $e',
        moduleId: action.id,
      );
    }
  }

  /// Validate generated service file.
  Future<void> _validateServiceFile() async {
    if (serviceManager == 'systemd') {
      try {
        List<String> args = ['systemd-analyze', 'verify'];

        if (isUserService) {
          args.add('--user');
        }

        args.add(destination);

        final result =
            await FileUtils.executeCommandWithPermissionsCrossPlatform(
              args[0],
              args.sublist(1),
              privilegeEscalation: _getPrivilegeEscalation(),
              requireElevation: requirePrivilegeEscalation && !isUserService,
              description: 'Validate systemd unit file',
            );

        if (result.exitCode != 0) {
          throw ActionFailedException(
            'Service file validation failed: ${result.stderr}',
            moduleId: action.id,
          );
        }
        logger.info('Service file validation passed');
      } catch (e) {
        if (e is ActionFailedException) {
          rethrow;
        }
        logger.warning('Could not validate service file: $e');
      }
    }
  }
}
