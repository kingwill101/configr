import 'dart:async';

import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/utils/event_bus.dart';
import 'package:configr/src/utils/fs.dart';
import 'package:file/file.dart';
// import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:contextual/contextual.dart';

final logger = Logger();

/// Initialize the logger.
///
/// [logDirectory] overrides the default log directory (XDG
/// `~/.config/configr/logs/`). The log file is written as `configr.log` inside
/// that directory.
void initLogging({String? logDirectory}) {
  logger.setLevel(.info);

  logger
    ..environment('development')
    ..withContext({'app': 'MyApp'})
    ..addChannel(
      'console',
      ConsoleLogDriver(),
      formatter: PrettyLogFormatter(),
    );
  // ..addChannel(
  //   'file',
  //   IsolateDailyFileLogDriver(
  //     logDirectory ?? p.join(appDirs.config, 'logs'),
  //     retentionDays: 7,
  //     flushInterval: Duration(milliseconds: 100),
  //   ),
  //   formatter: PlainTextLogFormatter(),
  // );
}
