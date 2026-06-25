import 'dart:convert';

import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:i3config/i3config_v2.dart' as i3;

class SlurpBlock extends ActionBlock {
  @override
  String get blockType => 'slurp';

  String src = '';

  SlurpBlock();

  @override
  Map<String, String> get additionalProperties => {
    if (src.isNotEmpty) 'src': src,
  };

  @override
  void resetState() {
    super.resetState();
    src = '';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    src = (context.getVariable('src') as String?) ?? '';
  }

  @override
  String dryRunSummary() {
    if (src.isEmpty) return '$blockType: (empty)';
    return '$blockType: $src';
  }

  @override
  Future<void> execute() async {
    if (src.isEmpty) {
      throw ActionFailedException('src is required for slurp', moduleId: id);
    }

    if (!await fileService.fileExists(src)) {
      throw ActionFailedException(
        'File not found: $src', moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Slurping file: $src',
    ));

    try {
      final content = await fileService.readBinaryFile(src);
      final encoded = base64Encode(content);

      context.setVariable('slurp_content', encoded);
      context.setVariable('slurp_encoding', 'base64');
      context.setVariable('slurp_size', content.length);

      emitEvent(CompletedEvent(
        moduleId: id,
        message: 'Slurped $src (${content.length} bytes)',
      ));
      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('slurp failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}
