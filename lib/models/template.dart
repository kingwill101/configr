class Template {
  Map<String, dynamic>? vars = {};
  String? template;

  Template({this.template, this.vars = const {}});

  @override
  String toString() {
    return 'Template(template: $template)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template &&
        other.template == template &&
        other.vars == vars;
  }

  @override
  int get hashCode => template.hashCode ^ vars.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'template': template,
      'vars': vars,
    };
  }

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      vars: json['vars'] as Map<String, dynamic>?,
      template: json['template'] as String?,
    );
  }

  String toConfig({String indent = ''}) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('${indent}template {');
    buffer.writeln('$indent  template $template');
    if (vars != null && vars!.isNotEmpty) {
      buffer.writeln('$indent  vars {');
      for (var entry in vars!.entries) {
        buffer.writeln('$indent    ${entry.key}: ${entry.value}');
      }
      buffer.writeln('$indent  }');
    }

    buffer.writeln('$indent}');
    return buffer.toString();
  }
}
