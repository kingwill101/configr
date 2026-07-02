/// Sentinel exception used to stop i3config processing after the first error.
class ConfigrProcessingHalted implements Exception {
  static const recordedPrefix = '__CONFIGR_RECORDED_ERROR__';

  final String message;
  final bool alreadyRecorded;

  const ConfigrProcessingHalted(this.message, {this.alreadyRecorded = false});

  static bool isRecordedMessage(String message) {
    return message.startsWith(recordedPrefix);
  }

  static String cleanMessage(String message) {
    if (!isRecordedMessage(message)) return message;
    return message.substring(recordedPrefix.length).trimLeft();
  }

  @override
  String toString() {
    if (alreadyRecorded) {
      return '$recordedPrefix $message';
    }
    return message;
  }
}
