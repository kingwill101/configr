import 'dart:async';

import 'package:configr/events/module_events.dart';
import 'package:configr/ui/handlers/base_handler.dart';
import 'package:termlib/termlib.dart';

/// Data structure for each module's UI state (spinner, progress, message, etc.)
class ModuleLineState {
  int spinnerIndex;
  bool hasSpinner;
  bool inProgress;
  bool hasProgress;
  int current;
  int total;
  String message;

  ModuleLineState({
    this.spinnerIndex = 0,
    this.hasSpinner = false,
    this.inProgress = false,
    this.hasProgress = false,
    this.current = 0,
    this.total = 100,
    this.message = '',
  });
}

/// A CLI handler that draws multiple modules on multiple lines using termlib.
class CLIHandler implements UIHandler {
  final TermLib terminal = TermLib();
  final int _initialCursorRow = 2;

  // Map from moduleId -> line index
  final Map<String, int> _moduleLineIndex = {};

  // Map from moduleId -> the data we need to draw
  final Map<String, ModuleLineState> _modules = {};

  bool _isActive = false;
  int _nextLineIndex = 0;

  // Timer to periodically update spinner frames
  Timer? _redrawTimer;

  // Spinner frames
  final List<String> _spinnerChars = ['|', '/', '-', '\\'];

  // Where do we start printing modules in the console?
  // In this example, row 2. (Row 0,1 can hold header messages, etc.)
  int get _topOffset => _initialCursorRow;

  String _infoPen(String text) => (terminal.style(text)
        ..fg(Color.white)
        ..bold())
      .toString();

  String _successPen(String text) => (terminal.style(text)
        ..fg(Color.green)
        ..bold())
      .toString();

  String _warningPen(String text) => (terminal.style(text)
        ..fg(Color.yellow)
        ..bold())
      .toString();

  String _errorPen(String text) => (terminal.style(text)
        ..fg(Color.red)
        ..bold())
      .toString();

  String _debugPen(String text) => (terminal.style(text)
        ..fg(Color.white)
        ..bg(Color.brightBlack)
        ..bold())
      .toString();

  void _assignLineIfNeeded(String moduleId) {
    if (!_modules.containsKey(moduleId)) {
      _modules[moduleId] = ModuleLineState();
    }
    if (!_moduleLineIndex.containsKey(moduleId)) {
      _moduleLineIndex[moduleId] = _nextLineIndex;
      _nextLineIndex++;
    }
  }

  String _buildLineText(ModuleLineState state) {
    final sb = StringBuffer();

    // Spinner
    if (state.hasSpinner && state.inProgress) {
      final spinIndex = state.spinnerIndex % _spinnerChars.length;
      sb.write('${_spinnerChars[spinIndex]} ');
      state.spinnerIndex++;
    }

    // Progress Bar
    if (state.hasProgress) {
      final pct = (state.current / state.total) * 100;
      const barSize = 20;
      final filled = ((pct / 100) * barSize).round();
      final bar = '=' * filled;
      final blank = ' ' * (barSize - filled);
      sb.write('[$bar$blank] ${pct.toStringAsFixed(1)}% ');
    }

    // Message
    sb.write(state.message);

    return sb.toString();
  }

  // Add field to track visible area
  final Map<String, bool> _visibleModules = {};

  void _redraw() {
    terminal.startSyncUpdate();

    try {
      final viewportHeight = terminal.windowHeight;
      final viewportStart = _initialCursorRow;
      final viewportEnd = viewportStart + viewportHeight;

      for (final entry in _moduleLineIndex.entries) {
        final moduleId = entry.key;
        final lineIndex = entry.value;
        final row = _topOffset + lineIndex;

        if (row >= viewportStart && row < viewportEnd) {
          final state = _modules[moduleId]!;
          terminal
            ..writeAt(row, 0, ' ' * terminal.windowWidth)
            ..writeAt(row, 0, _buildLineText(state));

          _visibleModules[moduleId] = true;
        } else {
          _visibleModules[moduleId] = false;
        }
      }
    } finally {
      terminal.endSyncUpdate();
    }
  }

  void _handleStarted(String moduleId, String message) {
    _assignLineIfNeeded(moduleId);
    final state = _modules[moduleId]!;

    state.hasSpinner = true;
    state.inProgress = true;
    state.message = message;
  }

  void _handleProgress(
    String moduleId,
    int current,
    int total,
    String message,
  ) {
    _assignLineIfNeeded(moduleId);
    final state = _modules[moduleId]!;

    state.hasProgress = true;
    state.inProgress = true;
    state.current = current;
    state.total = total;
    state.message = message;
  }

  void _handleCompleted(String moduleId, String message) {
    _assignLineIfNeeded(moduleId);
    final state = _modules[moduleId]!;

    // No more spinner/progress
    state.hasSpinner = false;
    state.inProgress = false;
    state.message = _successPen('✓ $message');
  }

  void _handleFailed(String moduleId, String message) {
    _assignLineIfNeeded(moduleId);
    final state = _modules[moduleId]!;

    state.hasSpinner = false;
    state.inProgress = false;
    state.message = _errorPen('✖ $message');
  }

  void _handleStatusUpdate(String moduleId, StatusEvent level, String message) {
    _assignLineIfNeeded(moduleId);
    final state = _modules[moduleId]!;

    switch (level) {
      case StatusEvent.info:
        state.message = _infoPen(message);
        break;
      case StatusEvent.warning:
        state.message = _warningPen('⚠ $message');
        break;
      case StatusEvent.error:
        state.message = _errorPen('✖ $message');
        break;
      case StatusEvent.debug:
        state.message = _debugPen('🔍 $message');
        break;
    }
  }

  @override
  void start() {
    _isActive = true;

    terminal
      ..eraseClear()
      ..cursorHide();

    // _redrawTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
    _redraw();
    // });
  }

  @override
  void stop() {
    _isActive = false;

    _redrawTimer?.cancel();
    _redrawTimer = null;

    _redraw();

    terminal
      ..writeAt(_topOffset + _nextLineIndex + 1, 0, '')
      ..cursorShow();

    _modules.clear();
    _moduleLineIndex.clear();
    _nextLineIndex = 0;
  }

  @override
  void handleEvent(ModuleEvent event) {
    if (!_isActive) return;

    switch (event) {
      case StartedEvent e:
        _handleStarted(e.moduleId, e.message);

      case ProgressEvent e:
        _handleProgress(e.moduleId, e.current, e.total, e.message);

      case CompletedEvent e:
        _handleCompleted(e.moduleId, e.message);

      case FailedEvent e:
        _handleFailed(e.moduleId, e.message);

      case StatusUpdateEvent e:
        _handleStatusUpdate(e.moduleId, e.level, e.message);

      case DownloadProgressEvent e:
        _handleProgress(e.moduleId, e.current, e.total, e.message);
    }
  }
}
