// Re-exports the real command runner from the executable entry point.
//
// This file exists for backwards compatibility with any tooling that
// imported it directly. The canonical entry point is bin/main.dart.

export '../bin/configr.dart' show ConfigrCommandRunner;
