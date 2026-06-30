import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:artisanal/args.dart';
import 'package:configr/src/cli/ui/handlers/cli_handler.dart';
import 'package:configr/src/cli/ui/handlers/interactive_handler.dart';
import 'package:configr/src/cli/ui/handlers/base_handler.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/configr_directories.dart';
import 'package:configr/src/configr_runtime.dart';
import 'package:configr/src/di.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/file_event_handler.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:configr/src/utils/privilege_escalation.dart';
import 'package:file/local.dart';

import 'package:configr/src/cli/cli_exit_exception.dart';
import 'package:configr/src/cli/commands/add.dart';
import 'package:configr/src/cli/commands/apply.dart';
import 'package:configr/src/cli/commands/base_command.dart';
import 'package:configr/src/cli/commands/config.dart';
import 'package:configr/src/cli/commands/diff.dart';
import 'package:configr/src/cli/commands/edit.dart';
import 'package:configr/src/cli/commands/format.dart';
import 'package:configr/src/cli/commands/init.dart';
import 'package:configr/src/cli/commands/package.dart';
import 'package:configr/src/cli/commands/rollback.dart';
import 'package:configr/src/cli/commands/hosts.dart';
import 'package:configr/src/cli/commands/status.dart';
import 'package:configr/src/cli/commands/watch.dart';
import 'package:configr/src/connection_config.dart';

class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner({
    void Function(String)? out,
    void Function(String)? err,
    void Function(String)? outRaw,
    void Function(String)? errRaw,
    String? Function()? readLine,
    void Function(int)? setExitCode,
    bool? ansi,
  }) : super(
         'configr',
         'A powerful configuration management tool for dotfiles and system configuration',
         out: out,
         err: err,
         outRaw: outRaw,
         errRaw: errRaw,
         readLine: readLine,
         setExitCode: setExitCode,
         ansi: ansi,
       ) {
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'Path to the configuration file (default: "config")',
      defaultsTo: 'config',
    );

    argParser.addFlag(
      'v2',
      help: 'Use the v2 i3config-based ActionBlock pipeline',
      defaultsTo: false,
    );

    argParser.addMultiOption(
      'plugin-dir',
      help:
          'Directory to discover plugins from (can be specified multiple times)',
      valueHelp: 'path',
    );

    argParser.addMultiOption(
      'plugin',
      help:
          'Path to a plugin file (.lua) to load (can be specified multiple times)',
      valueHelp: 'path',
    );

    argParser.addFlag(
      'debug',
      abbr: 'd',
      help:
          'Enable debug output with timestamps and detailed event information',
      defaultsTo: false,
    );

    argParser.addFlag(
      'dry-run',
      help:
          'Show what would be done without making changes (safe preview mode)',
      defaultsTo: false,
    );

    argParser.addFlag(
      'generate-completion',
      help: 'Generate shell completion script for the current shell',
      defaultsTo: false,
    );

    argParser.addOption(
      'host',
      help: 'SSH host to connect to for remote execution',
      valueHelp: 'hostname',
    );

    argParser.addOption(
      'ssh-port',
      help: 'SSH port (default: 22)',
      valueHelp: 'port',
      defaultsTo: '22',
    );

    argParser.addOption(
      'ssh-user',
      help: 'SSH username (default: root)',
      valueHelp: 'username',
      defaultsTo: 'root',
    );

    argParser.addOption(
      'ssh-password',
      help: 'SSH password',
      valueHelp: 'password',
    );

    argParser.addOption(
      'ssh-key',
      help: 'Path to SSH private key file',
      valueHelp: 'path',
    );

    argParser.addOption(
      'ssh-key-passphrase',
      help: 'Passphrase for the SSH private key',
      valueHelp: 'passphrase',
    );

    addCommand(InitCommand());
    addCommand(ApplyCommand());
    addCommand(DiffCommand());
    addCommand(ConfigCommand());
    addCommand(FormatCommand());
    addCommand(AddCommand());
    addCommand(EditCommand());
    addCommand(HostsCommand());
    addCommand(StatusCommand());
    addCommand(RollbackCommand());
    addCommand(WatchCommand());
    addCommand(PackageCommand());
  }

  @override
  Future<void> run(Iterable<String> args) async {
    // Parse args using the argParser instead of manual string matching.
    // The argParser already defines every option with proper types, defaults,
    // and error handling. We call parse() here to extract global option
    // values before delegating to super.run() for command dispatch.
    ArgResults? parsed;
    try {
      parsed = argParser.parse(args);
    } on ArgParserException {
      await super.run(args);
      return;
    }

    final configPath = parsed['config'] as String? ?? 'config';
    final configDir = path.dirname(path.absolute(configPath));
    final configrDirs = ConfigrDirectories(
      projectConfigrPath: path.join(configDir, '.configr'),
    );
    initLogging(logDirectory: configrDirs.logsDir);

    final useV2 = parsed['v2'] as bool? ?? false;
    final debugMode = parsed['debug'] as bool? ?? false;
    final dryRunMode = parsed['dry-run'] as bool? ?? false;
    final generateCompletion = parsed['generate-completion'] as bool? ?? false;
    final pluginDirs = (parsed['plugin-dir'] as List<String>?) ?? [];
    final pluginFiles = (parsed['plugin'] as List<String>?) ?? [];

    final sshHost = parsed['host'] as String?;
    final sshPort = int.tryParse(parsed['ssh-port'] as String? ?? '22') ?? 22;
    final sshUser = parsed['ssh-user'] as String? ?? 'root';
    final sshPassword = parsed['ssh-password'] as String?;
    final sshKeyPath = parsed['ssh-key'] as String?;
    final sshKeyPassphrase = parsed['ssh-key-passphrase'] as String?;

    ConnectionConfig? connectionConfig;
    if (sshHost != null && sshHost.isNotEmpty) {
      String? privateKey;
      if (sshKeyPath != null && sshKeyPath.isNotEmpty) {
        privateKey = File(sshKeyPath).readAsStringSync();
      }
      connectionConfig = ConnectionConfig(
        host: sshHost,
        port: sshPort,
        username: sshUser,
        password: sshPassword?.isNotEmpty == true ? sshPassword : null,
        privateKey: privateKey,
        privateKeyPassphrase: sshKeyPassphrase?.isNotEmpty == true
            ? sshKeyPassphrase
            : null,
      );
    }

    if (generateCompletion) {
      _generateCompletionScript();
      return;
    }

    // Verbosity: count -v/--verbose occurrences in raw args since
    // argParser reports --verbose as a boolean flag (negatable: false)
    // rather than a counted option.
    var vCount = 0;
    for (final arg in args) {
      if (arg == '--verbose' || arg == '-v') {
        vCount++;
      } else {
        final match = RegExp(r'^-v+$').firstMatch(arg);
        if (match != null) vCount += arg.length - 1;
      }
    }
    final verboseMode = vCount >= 1;
    final debugLevel = vCount >= 3;
    final interactiveMode =
        (parsed['no-interaction'] as bool? ?? false) == false;

    final eventBus = di.isRegistered<EventBus>() ? di<EventBus>() : EventBus();
    final fileSystem = const LocalFileSystem();

    final fileEventHandler = FileEventHandler(
      eventBus: eventBus,
      logFile: fileSystem
          .directory(configrDirs.logsDir)
          .childFile(
            'session-${DateTime.now().toIso8601String().replaceAll(':', '-')}.jsonl',
          ),
    );
    fileEventHandler.start();

    final uiHandler = interactiveMode
        ? InteractiveHandler(
            eventBus: eventBus,
            interactiveMode: true,
            console: io,
          )
        : CLIHandler(eventBus: eventBus, console: io) as UIHandler;

    final privilegeEscalation = di.isRegistered<PrivilegeEscalation>()
        ? di<PrivilegeEscalation>()
        : null;

    final configrConfig = ConfigrConfig(
      fileSystem: fileSystem,
      eventBus: eventBus,
      uiHandler: uiHandler,
      configPath: configPath,
      keepPrivilegeLock: false,
      localPath: fileSystem.currentDirectory.path,
      verboseMode: verboseMode || debugMode,
      debugMode: debugMode || debugLevel,
      dryRunMode: dryRunMode,
      interactiveMode: interactiveMode,
      useV2: useV2,
      pluginDirs: pluginDirs,
      pluginFiles: pluginFiles,
      privilegeEscalation: privilegeEscalation,
      connectionConfig: connectionConfig,
    );

    final runtime = ConfigrRuntime(configrConfig);

    for (final command in commands.values) {
      if (command is BaseCommand) {
        command.runtime = runtime;
      }
    }

    try {
      await super.run(args);
    } on CliExitException {
      rethrow;
    } finally {
      fileEventHandler.stop();
      uiHandler.stop();
      // await logger.shutdown();
    }
  }

  // ---------------------------------------------------------------------------
  // Shell completion generation
  // ---------------------------------------------------------------------------

  void _generateCompletionScript() {
    final shell = Platform.environment['SHELL'] ?? '/bin/bash';
    final shellName = path.basename(shell);

    print('Generating completion script for $shellName...');
    print('');

    switch (shellName) {
      case 'bash':
        _generateBashCompletion();
        break;
      case 'zsh':
        _generateZshCompletion();
        break;
      case 'fish':
        _generateFishCompletion();
        break;
      default:
        print('Unsupported shell: $shellName');
        print('Supported shells: bash, zsh, fish');
        print(
          'You can manually specify the shell by setting the SHELL environment variable',
        );
        throw CliExitException(1);
    }
  }

  void _generateBashCompletion() {
    print('''
# Bash completion for configr
# Add this to your ~/.bashrc or ~/.bash_profile

_configr_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"

    local commands="init apply diff format add edit status rollback"

    local global_opts="--config -c --v2 --debug -d --dry-run --generate-completion"
    local artisanal_opts="--verbose -v --quiet -q --no-interaction -n --ansi --no-ansi --help"

    case \${COMP_CWORD} in
        1)
            COMPREPLY=( \$(compgen -W "\$commands" -- \${cur}) )
            return 0
            ;;
        2)
            case \${prev} in
                --config|-c)
                    COMPREPLY=( \$(compgen -f -- \${cur}) )
                    return 0
                    ;;
                *)
                    COMPREPLY=( \$(compgen -W "\$global_opts \$artisanal_opts" -- \${cur}) )
                    return 0
                    ;;
            esac
            ;;
        *)
            COMPREPLY=( \$(compgen -W "\$global_opts \$artisanal_opts" -- \${cur}) )
            return 0
            ;;
    esac
}

complete -F _configr_completion configr

echo "Bash completion installed. Restart your shell or run 'source ~/.bashrc'"
''');
  }

  void _generateZshCompletion() {
    print('''
# Zsh completion for configr
# Add this to your ~/.zshrc

_configr() {
    local context state line
    typeset -A opt_args

    _arguments -C \\
        '1: :->commands' \\
        '*::arg:->args' \\
        '--config[Path to configuration file]:file:_files' \\
        '-c[Path to configuration file]:file:_files' \\
        '--v2[Use the v2 i3config-based pipeline]' \\
        '--debug[Enable debug output]' \\
        '-d[Enable debug output]' \\
        '--dry-run[Show what would be done without making changes]' \\
        '--verbose[Increase verbosity (-v = verbose, -vv = very verbose, -vvv = debug)]' \\
        '-v[Increase verbosity]' \\
        '--quiet[Suppress output]' \\
        '-q[Suppress output]' \\
        '--no-interaction[Disable interactive prompts]' \\
        '-n[Disable interactive prompts]' \\
        '--ansi[Force ANSI output]' \\
        '--no-ansi[Disable ANSI output]' \\
        '--generate-completion[Generate shell completion script]' \\
        '--help[Show help]' \\
        && return 0

    case \$state in
        commands)
            _values 'commands' \\
                'init[Initialize a new configuration]' \\
                'apply[Apply configuration]' \\
                'diff[Show differences]' \\
                'format[Format configuration file]' \\
                'add[Add new resource]' \\
                'edit[Edit configuration]' \\
                'status[Show status]' \\
                'rollback[Rollback changes]' \\
            ;;
    esac
}

compdef _configr configr

echo "Zsh completion installed. Restart your shell or run 'source ~/.zshrc'"
''');
  }

  void _generateFishCompletion() {
    print('''
# Fish completion for configr
# Save this to ~/.config/fish/completions/configr.fish

complete -c configr -f

complete -c configr -n "__fish_use_subcommand" -a "init" -d "Initialize a new configuration"
complete -c configr -n "__fish_use_subcommand" -a "apply" -d "Apply configuration"
complete -c configr -n "__fish_use_subcommand" -a "diff" -d "Show differences"
complete -c configr -n "__fish_use_subcommand" -a "format" -d "Format configuration file"
complete -c configr -n "__fish_use_subcommand" -a "add" -d "Add new resource"
complete -c configr -n "__fish_use_subcommand" -a "edit" -d "Edit configuration"
complete -c configr -n "__fish_use_subcommand" -a "status" -d "Show status"
complete -c configr -n "__fish_use_subcommand" -a "rollback" -d "Rollback changes"

complete -c configr -s c -l config -d "Path to configuration file" -r
complete -c configr -l v2 -d "Use the v2 i3config-based pipeline"
complete -c configr -s d -l debug -d "Enable debug output"
complete -c configr -l dry-run -d "Show what would be done without making changes"
complete -c configr -l generate-completion -d "Generate shell completion script"
complete -c configr -s v -l verbose -d "Increase verbosity (-v, -vv, -vvv)"
complete -c configr -s q -l quiet -d "Suppress output"
complete -c configr -s n -l no-interaction -d "Disable interactive prompts"
complete -c configr -l ansi -d "Force ANSI output"
complete -c configr -l no-ansi -d "Disable ANSI output"
complete -c configr -s h -l help -d "Show help"

echo "Fish completion installed. Restart your shell to use it."
''');
  }
}
