// Configr CLI entry point.
//
// This is the executable that `dart run configr` resolves to.
// Command implementations are in cli/commands/.
//
// Uses the artisanal CLI framework for styled output, verbosity levels,
// and interactive prompts. Custom flags (--config, --v2, --debug,
// --dry-run, --generate-completion) are added on top of artisanal's
// built-in flags (--verbose/-v, --quiet/-q, --no-interaction/-n, --ansi).

import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:artisanal/args.dart';
import 'package:configr/src/cli/ui/handlers/cli_handler.dart';
import 'package:configr/src/cli/ui/handlers/interactive_handler.dart';
import 'package:configr/src/configr_config.dart';
import 'package:configr/src/configr_runtime.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/logging.dart';
import 'package:file/local.dart';

import 'package:configr/src/cli/commands/add.dart';
import 'package:configr/src/cli/commands/apply.dart';
import 'package:configr/src/cli/commands/base_command.dart';
import 'package:configr/src/cli/commands/diff.dart';
import 'package:configr/src/cli/commands/edit.dart';
import 'package:configr/src/cli/commands/format.dart';
import 'package:configr/src/cli/commands/init.dart';
import 'package:configr/src/cli/commands/rollback.dart';
import 'package:configr/src/cli/commands/status.dart';
import 'package:configr/src/cli/commands/watch.dart';

class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner()
    : super(
        'configr',
        'A powerful configuration management tool for dotfiles and system configuration',
      ) {
    // Custom global flags on top of artisanal's built-in ones:
    //   --verbose/-v, --quiet/-q, --no-interaction/-n, --ansi/--no-ansi

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

    addCommand(InitCommand());
    addCommand(ApplyCommand());
    addCommand(DiffCommand());
    addCommand(FormatCommand());
    addCommand(AddCommand());
    addCommand(EditCommand());
    addCommand(StatusCommand());
    addCommand(RollbackCommand());
    addCommand(WatchCommand());
  }

  @override
  Future<void> run(Iterable<String> args) async {
    initLogging();

    // Extract custom-global-flag values from raw args.  We can't use
    // argParser.parse() here because the artisanal runner's run() — which we
    // call via super.run() — does its own full parse internally.  Scanning
    // raw strings avoids any double-parse conflicts.
    final configPath = _argValue(args, '--config', '-c') ?? 'config';
    final useV2 = _hasFlag(args, '--v2');
    final debugMode = _hasFlag(args, '--debug', '-d');
    final dryRunMode = _hasFlag(args, '--dry-run');
    final generateCompletion = _hasFlag(args, '--generate-completion');
    final pluginDirs = _multiArgValues(args, '--plugin-dir');
    final pluginFiles = _multiArgValues(args, '--plugin');

    if (generateCompletion) {
      _generateCompletionScript();
      return;
    }

    // Resolve verbosity/interactive the same way artisanal does internally.
    final verboseMode = _verbosityLevel(args) >= 1;
    final debugLevel = _verbosityLevel(args) >= 3;
    final interactiveMode = !_hasFlag(args, '--no-interaction', '-n');

    final eventBus = EventBus();
    final uiHandler = interactiveMode
        ? InteractiveHandler(
            eventBus: eventBus,
            interactiveMode: true,
          ) as dynamic
        : CLIHandler(eventBus: eventBus) as dynamic;

    final configrConfig = ConfigrConfig(
      fileSystem: const LocalFileSystem(),
      eventBus: eventBus,
      uiHandler: uiHandler,
      configPath: configPath,
      keepPrivilegeLock: false,
      localPath: const LocalFileSystem().currentDirectory.path,
      verboseMode: verboseMode || debugMode,
      debugMode: debugMode || debugLevel,
      dryRunMode: dryRunMode,
      interactiveMode: interactiveMode,
      useV2: useV2,
      pluginDirs: pluginDirs,
      pluginFiles: pluginFiles,
    );

    final runtime = ConfigrRuntime(configrConfig);

    for (final command in commands.values) {
      if (command is BaseCommand) {
        command.runtime = runtime;
      }
    }

    await super.run(args);
  }

  // ---------------------------------------------------------------------------
  // Raw-arg helpers (avoid double-parsing with artisanal's built-in parsing)
  // ---------------------------------------------------------------------------

  /// Returns values of a `--long=value1,value2` or multiple `--long value` flags.
  List<String> _multiArgValues(Iterable<String> args, String long) {
    final list = args.toList();
    final values = <String>[];
    for (int i = 0; i < list.length; i++) {
      if (list[i] == long) {
        if (i + 1 < list.length && !list[i + 1].startsWith('-')) {
          values.add(list[i + 1]);
        }
      }
      if (list[i].startsWith('$long=')) {
        final val = list[i].substring('$long='.length);
        for (final part in val.split(',')) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) values.add(trimmed);
        }
      }
    }
    return values;
  }

  /// Returns the value of a `--long=value` or `--long value` / `-s value` flag.
  String? _argValue(Iterable<String> args, String long, String short) {
    final list = args.toList();
    for (int i = 0; i < list.length; i++) {
      if (list[i] == long || list[i] == short) {
        if (i + 1 < list.length && !list[i + 1].startsWith('-')) {
          return list[i + 1];
        }
      }
      if (list[i].startsWith('$long=')) {
        return list[i].substring('$long='.length);
      }
      if (list[i].startsWith('$short=')) {
        return list[i].substring('$short='.length);
      }
    }
    return null;
  }

  /// Returns `true` if the flag appears in raw [args].
  bool _hasFlag(Iterable<String> args, String long, [String? short]) {
    for (final arg in args) {
      if (arg == long) return true;
      if (short != null && arg == short) return true;
    }
    return false;
  }

  /// Count verbosity levels from raw args: 0 = none, 1 = -v, 2 = -vv, 3 = -vvv
  int _verbosityLevel(Iterable<String> args) {
    var count = 0;
    for (final arg in args) {
      if (arg == '--verbose' || arg == '-v') {
        count++;
        continue;
      }
      // Handle -vv, -vvv
      final match = RegExp(r'^-v+$').firstMatch(arg);
      if (match != null) {
        count += arg.length - 1;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Shell completion generation
  // ---------------------------------------------------------------------------

  void _generateCompletionScript() {
    final shell = Platform.environment['SHELL'] ?? '/bin/bash';
    final shellName = path.basename(shell);

    print('🔧 Generating completion script for $shellName...');
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
        print('❌ Unsupported shell: $shellName');
        print('💡 Supported shells: bash, zsh, fish');
        print(
          '💡 You can manually specify the shell by setting the SHELL environment variable',
        );
        exit(1);
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

echo "✅ Bash completion installed. Restart your shell or run 'source ~/.bashrc'"
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

echo "✅ Zsh completion installed. Restart your shell or run 'source ~/.zshrc'"
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

echo "✅ Fish completion installed. Restart your shell to use it."
''');
  }
}

void main(List<String> arguments) async {
  final runner = ConfigrCommandRunner();

  try {
    await runner.run(arguments);
  } on FormatException catch (e) {
    print('❌ Configuration Error: ${e.message}');
    print('💡 Tip: Check your configuration file syntax and format');
    exit(1);
  } on FileSystemException catch (e) {
    print('❌ File System Error: ${e.message}');
    print('💡 Tip: Check file permissions and paths: ${e.path}');
    exit(1);
  } on ProcessException catch (e) {
    print('❌ Process Error: ${e.message}');
    print('💡 Tip: Make sure required commands are installed and accessible');
    exit(1);
  } on ArgumentError catch (e) {
    print('❌ Argument Error: ${e.message}');
    print('💡 Tip: Check command arguments and options');
    exit(1);
  } catch (e, stackTrace) {
    print('❌ Unexpected Error: $e');
    print('💡 Tip: Use --debug flag for detailed error information');
    logger.severe('Unexpected error: $e', e, stackTrace);
    exit(1);
  }
}
