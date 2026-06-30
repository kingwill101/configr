import 'package:configr/src/di.dart';
import 'package:configr/src/utils/command_runner.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/execution_service.dart';
import 'package:configr/src/utils/file_service.dart';
import 'package:configr/src/utils/network_service.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;

/// Registers core DI services needed by ActionBlock execution (apply & rollback).
///
/// Every parameter is optional — sensible defaults are used when omitted.
/// This single function is the **source of truth** for block-level DI.
/// Both [applyV2] and [rollbackV2] (in `v2_apply.dart`) call this instead
/// of wiring DI by hand.
void registerCoreDiServices({
  bool dryRun = false,
  EventBus? eventBus,
  PrivilegeEscalation? privilegeEscalation,
  FileSystem? fileSystem,
  ExecutionService? executionService,
  NetworkService? networkService,
}) {
  final exec = executionService ?? const LocalExecutionService();
  final fs = fileSystem ?? const LocalFileSystem();
  di
    ..allowReassignment = true
    ..registerSingleton<DryRunFlag>(DryRunFlag(dryRun))
    ..registerSingleton<EventBus>(eventBus ?? EventBus())
    ..registerSingleton<PrivilegeEscalation>(
      privilegeEscalation ?? NonInteractiveSudoEscalation(),
    )
    ..registerSingleton<FileSystem>(fs)
    ..registerSingleton<ExecutionService>(exec)
    ..registerSingleton<NetworkService>(
      networkService ??
          (exec is LocalExecutionService
              ? LocalNetworkService(fileSystem: fs)
              : ExecutionNetworkService(exec)),
    )
    ..registerSingleton<FileService>(LocalFileService())
    ..registerSingleton<CommandRunner>(const LocalCommandRunner())
    ..allowReassignment = false;
}
