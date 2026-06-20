enum ModuleGroupType { package, resource }

class ModuleGroup {
  final String? name;
  final List<String> items;
  final ModuleGroupType type;
  final Map<String, String> properties;

  ModuleGroup({
    this.name,
    this.items = const [],
    this.type = ModuleGroupType.package,
    this.properties = const {},
  });
}
