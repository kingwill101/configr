// bin/main.dart

import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:args/command_runner.dart';
import 'package:configr/commands/add.dart';
import 'package:configr/commands/apply.dart';
import 'package:configr/commands/base_command.dart';
import 'package:configr/commands/diff.dart';
import 'package:configr/commands/edit.dart';
import 'package:configr/commands/format.dart';
import 'package:configr/commands/init.dart';
import 'package:configr/commands/rollback.dart';
import 'package:configr/commands/status.dart';
import 'package:configr/config_manager.dart';
import 'package:configr/utils/fs.dart';
import 'package:configr/utils/logging.dart';

class ConfigrCommandRunner extends CommandRunner<void> {
  ConfigrCommandRunner() : super('configr', 'A powerful configuration management tool for dotfiles and system configuration') {
    // Global options
    argParser.addOption(
      'config',
      abbr: 'c',
      help: 'Path to the configuration file (default: "config")',
      defaultsTo: 'config',
    );
    
    argParser.addFlag(
      'interactive',
      abbr: 'i',
      help: 'Enable interactive mode with guided prompts and confirmations',
      defaultsTo: false,
    );
    
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose output with detailed progress information',
      defaultsTo: false,
    );
    
    argParser.addFlag(
      'debug',
      abbr: 'd',
      help: 'Enable debug output with timestamps and detailed event information',
      defaultsTo: false,
    );
    
    argParser.addFlag(
      'dry-run',
      help: 'Show what would be done without making any changes (safe preview mode)',
      defaultsTo: false,
    );
    
    argParser.addFlag(
      'generate-completion',
      help: 'Generate shell completion script for the current shell',
      defaultsTo: false,
    );

    // Add commands
    addCommand(InitCommand());
    addCommand(ApplyCommand());
    addCommand(DiffCommand());
    addCommand(FormatCommand());
    addCommand(AddCommand());
    addCommand(EditCommand());
    addCommand(StatusCommand());
    addCommand(RollbackCommand());
  }

  @override
  Future<void> run(Iterable<String> args) async {
    initLogging();
    
    // Parse arguments first to get config path and flags
    final argResults = argParser.parse(args);
    final configPath = argResults['config'] as String? ?? 'config';
    final interactiveMode = argResults['interactive'] as bool? ?? false;
    final verboseMode = argResults['verbose'] as bool? ?? false;
    final debugMode = argResults['debug'] as bool? ?? false;
    final dryRunMode = argResults['dry-run'] as bool? ?? false;
    final generateCompletion = argResults['generate-completion'] as bool? ?? false;
    
    final configManager = ConfigManager(
      repoUrl: 'https://github.com/yourusername/dotfiles.git',
      path: fs.currentDirectory.path,
      fileSystem: fs,
      privilegeEscalation: null, // Will be created internally with UI handler
      configPath: configPath,
      interactiveMode: interactiveMode,
      verboseMode: verboseMode,
      debugMode: debugMode,
      dryRunMode: dryRunMode,
    );

    // Handle completion generation
    if (generateCompletion) {
      _generateCompletionScript();
      return;
    }

    // Set the config manager for all commands
    for (final command in commands.values) {
      if (command is BaseCommand) {
        command.configManager = configManager;
      }
    }

    await super.run(args);
  }

  /// Generate shell completion script
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
        print('💡 You can manually specify the shell by setting the SHELL environment variable');
        exit(1);
    }
  }

  /// Generate bash completion script
  void _generateBashCompletion() {
    print('''
# Bash completion for configr
# Add this to your ~/.bashrc or ~/.bash_profile

_configr_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    
    # Commands
    local commands="init apply diff format add edit status rollback"
    
    # Global options
    local global_opts="--config --interactive --verbose --debug --dry-run --generate-completion --help"
    
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
                    COMPREPLY=( \$(compgen -W "\$global_opts" -- \${cur}) )
                    return 0
                    ;;
            esac
            ;;
        *)
            COMPREPLY=( \$(compgen -W "\$global_opts" -- \${cur}) )
            return 0
            ;;
    esac
}

complete -F _configr_completion configr

echo "✅ Bash completion installed. Restart your shell or run 'source ~/.bashrc'"
''');
  }

  /// Generate zsh completion script
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
        '--interactive[Enable interactive mode]' \\
        '--verbose[Enable verbose output]' \\
        '--debug[Enable debug output]' \\
        '--dry-run[Show what would be done without making changes]' \\
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

  /// Generate fish completion script
  void _generateFishCompletion() {
    print('''
# Fish completion for configr
# Save this to ~/.config/fish/completions/configr.fish

complete -c configr -f

# Commands
complete -c configr -n "__fish_use_subcommand" -a "init" -d "Initialize a new configuration"
complete -c configr -n "__fish_use_subcommand" -a "apply" -d "Apply configuration"
complete -c configr -n "__fish_use_subcommand" -a "diff" -d "Show differences"
complete -c configr -n "__fish_use_subcommand" -a "format" -d "Format configuration file"
complete -c configr -n "__fish_use_subcommand" -a "add" -d "Add new resource"
complete -c configr -n "__fish_use_subcommand" -a "edit" -d "Edit configuration"
complete -c configr -n "__fish_use_subcommand" -a "status" -d "Show status"
complete -c configr -n "__fish_use_subcommand" -a "rollback" -d "Rollback changes"

# Global options
complete -c configr -s c -l config -d "Path to configuration file" -r
complete -c configr -s i -l interactive -d "Enable interactive mode"
complete -c configr -s v -l verbose -d "Enable verbose output"
complete -c configr -s d -l debug -d "Enable debug output"
complete -c configr -l dry-run -d "Show what would be done without making changes"
complete -c configr -l generate-completion -d "Generate shell completion script"
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
