import 'package:configr/utils/logging.dart';
import 'package:interact/interact.dart';

dialog(
  String prompt, {
  bool defaultValue = false,
  Function? onReject,
  Function? onAccept,
}) async {
  final answer = Confirm(
    prompt: prompt,
    defaultValue: true, // this is optional
    waitForNewLine: true, // optional and will be false by default
  ).interact();

  logger.info('Dialog answer: $answer');
  if (answer) {
    if (onAccept != null) {
      try {
        onAccept();
      } catch (e) {
        rethrow;
      }
    }
  } else {
    if (onReject != null) {
      logger.info('onReject called');
      onReject();
    }
  }
}

select(String prompt,
    {bool defaultValue = false,
    List<String> options = const [],
    defaultValueIndex = 0,
    Function(int)? onSelect}) async {
  final selection = Select(
    prompt: 'Your favorite programming language',
    options: options,
    initialIndex: defaultValueIndex, // optional, will be 0 by default
  ).interact();
  if (onSelect != null) {
    onSelect(selection);
  }
}
