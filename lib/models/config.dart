import 'package:configr/models/command.dart';
import 'package:configr/models/file_model.dart';
import 'package:configr/models/package.dart';

class ConfigOptions {
  final bool failFast;
  final bool interactive;
  final bool dryRun;

  const ConfigOptions({
    this.failFast = true,
    this.interactive = true,
    this.dryRun = false,
    this.force = false,
  });

  final bool force;

  ConfigOptions copyWith({
    bool? failFast,
    bool? interactive,
    bool? dryRun,
  }) {
    return ConfigOptions(
      failFast: failFast ?? this.failFast,
      interactive: interactive ?? this.interactive,
      dryRun: dryRun ?? this.dryRun,
    );
  }
}

class Config {
  ConfigOptions options;
  List<ResourceModel> resources;
  bool failFast;
  List<Command> commands;
  List<Package> packages;
  List<String> preApplyScripts;
  List<String> postApplyScripts;

  Config({
    List<ResourceModel>? resources,
    List<Command>? commands,
    List<Package>? packages,
    List<String>? preApplyScripts,
    List<String>? postApplyScripts,
    bool? shouldFailFast,
    ConfigOptions? options,
  })  : options = options ?? ConfigOptions(),
        failFast = shouldFailFast ?? true,
        resources = resources ?? [],
        commands = commands ?? [],
        packages = packages ?? [],
        preApplyScripts = preApplyScripts ?? [],
        postApplyScripts = postApplyScripts ?? [];

  @override
  int get hashCode => Object.hash(
        Object.hashAll(resources),
        Object.hashAll(commands),
        Object.hashAll(packages),
        Object.hashAll(preApplyScripts),
        Object.hashAll(postApplyScripts),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Config &&
          runtimeType == other.runtimeType &&
          failFast == other.failFast &&
          resources == other.resources &&
          commands == other.commands &&
          packages == other.packages &&
          preApplyScripts == other.preApplyScripts &&
          postApplyScripts == other.postApplyScripts;

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      resources: (json['resources'] as List<dynamic>?)
              ?.map((e) => ResourceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      commands: (json['commands'] as List<dynamic>?)
              ?.map((e) => Command.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      packages: (json['packages'] as List<dynamic>?)
              ?.map((e) => Package.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      preApplyScripts: (json['preApplyScripts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      postApplyScripts: (json['postApplyScripts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resources': resources.map((e) => e.toJson()).toList(),
      'commands': commands.map((e) => e.toJson()).toList(),
      'packages': packages.map((e) => e.toJson()).toList(),
      'preApplyScripts': preApplyScripts,
      'postApplyScripts': postApplyScripts,
    };
  }

  @override
  String toString() {
    return 'Config(resources: $resources, commands: $commands, packages: $packages, preApplyScripts: $preApplyScripts, postApplyScripts: $postApplyScripts)';
  }

  String toConfig() {
    StringBuffer buffer = StringBuffer();

    if (resources.isNotEmpty) {
      buffer.writeln('resources {');
      for (var file in resources) {
        buffer.write(file.toConfig(indent: '  '));
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    if (commands.isNotEmpty) {
      buffer.writeln('commands {');
      for (var command in commands) {
        buffer.write(command.toConfig(indent: '  '));
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    if (packages.isNotEmpty) {
      buffer.writeln('packages {');
      for (var package in packages) {
        buffer.write(package.toConfig(indent: '  '));
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    if (preApplyScripts.isNotEmpty) {
      buffer.writeln('pre_apply_scripts {');
      for (var script in preApplyScripts) {
        buffer.writeln('  "$script"');
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    if (postApplyScripts.isNotEmpty) {
      buffer.writeln('post_apply_scripts {');
      for (var script in postApplyScripts) {
        buffer.writeln('  "$script"');
      }
      buffer.writeln('}');
    }

    return buffer.toString();
  }

  Config copyWith({
    List<ResourceModel>? resources,
    List<Command>? commands,
    List<Package>? packages,
    List<String>? preApplyScripts,
    List<String>? postApplyScripts,
    bool? failFast,
    ConfigOptions? options,
  }) {
    return Config(
      resources: resources ?? this.resources,
      commands: commands ?? this.commands,
      packages: packages ?? this.packages,
      preApplyScripts: preApplyScripts ?? this.preApplyScripts,
      postApplyScripts: postApplyScripts ?? this.postApplyScripts,
      shouldFailFast: failFast ?? this.failFast,
      options: options ?? this.options,
    );
  }
}
