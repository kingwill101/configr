import 'package:mustache_template/mustache.dart';

class TemplateRenderer {
  Future<String> render(String template, Map<String, dynamic> context) async {
    final renderer = Template(template, htmlEscapeValues: false);
    return renderer.renderString(context);
  }
}
