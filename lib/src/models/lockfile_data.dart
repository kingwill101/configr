import 'file_model.dart';
import 'command.dart';
import 'package.dart';

class LockfileData {
  final List<ResourceModel> resources;
  final List<Command> commands;
  final List<Package> packages;
  final String configChecksum;

  LockfileData({
    required this.resources,
    required this.commands,
    required this.packages,
    required this.configChecksum,
  });

  factory LockfileData.fromJson(Map<String, dynamic> json) {
    return LockfileData(
      resources: (json['resources'] as List)
          .map((f) => ResourceModel.fromJson(f))
          .toList(),
      commands:
          (json['commands'] as List).map((c) => Command.fromJson(c)).toList(),
      packages:
          (json['packages'] as List).map((p) => Package.fromJson(p)).toList(),
      configChecksum: json['configChecksum'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'resources': resources.map((f) => f.toJson()).toList(),
        'commands': commands.map((c) => c.toJson()).toList(),
        'packages': packages.map((p) => p.toJson()).toList(),
        'configChecksum': configChecksum,
      };

  @override
  String toString() {
    return 'LockfileData(resources: $resources, commands: $commands, packages: $packages)';
  }
}
