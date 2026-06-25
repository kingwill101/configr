import 'package:configr/src/blocks/action_block.dart';
import 'package:configr/src/events/module_events.dart';
import 'package:configr/src/exceptions.dart';
import 'package:configr/src/utils/platform.dart';

import 'package:i3config/i3config_v2.dart' as i3;

class _FstabEntry {
  final String src;
  final String path;
  final String fstype;
  final String opts;
  final int dump;
  final int passno;

  const _FstabEntry({
    required this.src,
    required this.path,
    required this.fstype,
    required this.opts,
    this.dump = 0,
    this.passno = 0,
  });

  String toLine() => '$src  $path  $fstype  $opts  $dump  $passno';

  static _FstabEntry? parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    return _FstabEntry(
      src: parts[0],
      path: parts[1],
      fstype: parts[2],
      opts: parts.length > 3 ? parts[3] : 'defaults',
      dump: parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0,
      passno: parts.length > 5 ? int.tryParse(parts[5]) ?? 0 : 0,
    );
  }

  bool matchesPath(String mountPath) => path == mountPath;
}

abstract class MountBlock extends ActionBlock {
  @override
  String get blockType => 'mount';

  String path = '';
  String src = '';
  String fstype = '';
  String opts = 'defaults';
  int dump = 0;
  int passno = 0;
  String state = 'present';

  factory MountBlock() {
    final facts = OsFacts.detect();
    switch (facts.os) {
      case OperatingSystem.linux:
        return _LinuxMountBlock();
      case OperatingSystem.macos:
        return _MacOSMountBlock();
      case OperatingSystem.freebsd:
        return _FreeBSDMountBlock();
      default:
        return _UnsupportedMountBlock(facts);
    }
  }

  MountBlock._();

  @override
  Map<String, String> get additionalProperties => {
    if (path.isNotEmpty) 'path': path,
    if (src.isNotEmpty) 'src': src,
    if (fstype.isNotEmpty) 'fstype': fstype,
    if (opts != 'defaults') 'opts': opts,
    if (dump != 0) 'dump': dump.toString(),
    if (passno != 0) 'passno': passno.toString(),
    if (state != 'present') 'state': state,
  };

  @override
  void resetState() {
    super.resetState();
    path = '';
    src = '';
    fstype = '';
    opts = 'defaults';
    dump = 0;
    passno = 0;
    state = 'present';
  }

  @override
  Future<void> readAdditionalProperties(
    i3.Block block,
    i3.Context context,
  ) async {
    await super.readAdditionalProperties(block, context);
    path = (context.getVariable('path') as String?) ?? '';
    src = (context.getVariable('src') as String?) ?? '';
    fstype = (context.getVariable('fstype') as String?) ?? '';
    opts = (context.getVariable('opts') as String?) ?? 'defaults';
    dump = switch (context.getVariable('dump')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    passno = switch (context.getVariable('passno')) {
      final int v => v,
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    state = (context.getVariable('state') as String?) ?? 'present';
  }

  @override
  String dryRunSummary() {
    if (path.isNotEmpty) {
      return '$blockType: $state $path${src.isNotEmpty ? ' ($src)' : ''}';
    }
    return '';
  }

  String get fstabPath => '/etc/fstab';

  Future<List<String>> _readFstabLines() async {
    if (!await fileService.fileExists(fstabPath)) return [];
    final content = await fileService.readFile(fstabPath);
    return content.split('\n');
  }

  Future<void> _writeFstabLines(List<String> lines) async {
    await fileService.writeFileWithPermissions(
      fstabPath,
      '${lines.join('\n')}\n',
      requireElevation: true,
    );
  }

  Future<int> _findFstabEntry(String mountPath) async {
    final lines = await _readFstabLines();
    for (int i = 0; i < lines.length; i++) {
      final entry = _FstabEntry.parse(lines[i]);
      if (entry != null && entry.matchesPath(mountPath)) return i;
    }
    return -1;
  }

  Future<bool> _ensureFstabEntry() async {
    final lines = await _readFstabLines();
    final index = await _findFstabEntry(path);
    final newLine = _FstabEntry(
      src: src,
      path: path,
      fstype: fstype,
      opts: opts,
      dump: dump,
      passno: passno,
    ).toLine();

    if (index >= 0) {
      if (lines[index].trim() == newLine.trim()) return false;
      lines[index] = newLine;
      await _writeFstabLines(lines);
      return true;
    }

    lines.add(newLine);
    await _writeFstabLines(lines);
    return true;
  }

  Future<bool> _removeFstabEntry() async {
    final lines = await _readFstabLines();
    int removedCount = 0;
    lines.removeWhere((line) {
      final entry = _FstabEntry.parse(line);
      if (entry != null && entry.matchesPath(path)) {
        removedCount++;
        return true;
      }
      return false;
    });
    if (removedCount > 0) {
      await _writeFstabLines(lines);
      return true;
    }
    return false;
  }

  Future<bool> _isMounted() async {
    final result = await runCommand('mount', [], requireElevation: true, checkExitCode: false);
    if (result.exitCode != 0) return false;
    final output = result.stdout as String;
    for (final line in output.split('\n')) {
      if (line.contains(' on $path ')) return true;
    }
    return false;
  }

  Future<void> _mount() async {
    final args = <String>[];
    if (fstype.isNotEmpty && fstype != 'auto') {
      args.addAll(['-t', fstype]);
    }
    if (opts.isNotEmpty && opts != 'defaults') {
      args.addAll(['-o', opts]);
    }
    if (src.isNotEmpty) args.add(src);
    args.add(path);

    await runCommand('mount', args, requireElevation: true);
  }

  Future<void> _umount() async {
    await runCommand('umount', [path], requireElevation: true);
  }

  @override
  Future<void> execute() async {
    if (path.isEmpty) {
      throw ActionFailedException(
        'path is required for mount block', moduleId: id,
      );
    }

    emitEvent(StartedEvent(
      moduleId: id,
      message: 'Managing mount: $path (state=$state)',
    ));

    try {
      switch (state) {
        case 'present':
          final changed = await _ensureFstabEntry();
          if (changed) {
            emitEvent(CompletedEvent(
              moduleId: id,
              message: 'Mount entry for $path ensured in fstab',
            ));
          } else {
            emitEvent(StatusUpdateEvent(
              moduleId: id,
              message: 'Mount $path already present in fstab',
              level: StatusEvent.info,
            ));
          }

        case 'mounted':
          final fstabChanged = await _ensureFstabEntry();
          if (!await _isMounted()) {
            await _mount();
            emitEvent(CompletedEvent(
              moduleId: id,
              message: 'Mount $path mounted and fstab updated',
            ));
          } else if (fstabChanged) {
            emitEvent(CompletedEvent(
              moduleId: id,
              message: 'Mount $path already mounted, fstab updated',
            ));
          } else {
            emitEvent(StatusUpdateEvent(
              moduleId: id,
              message: 'Mount $path already at desired state',
              level: StatusEvent.info,
            ));
          }

        case 'absent':
          bool changed = false;
          if (await _isMounted()) {
            await _umount();
            changed = true;
          }
          final fstabRemoved = await _removeFstabEntry();
          if (changed || fstabRemoved) {
            emitEvent(CompletedEvent(
              moduleId: id,
              message: 'Mount $path removed from fstab and unmounted',
            ));
          } else {
            emitEvent(StatusUpdateEvent(
              moduleId: id,
              message: 'Mount $path is already absent',
              level: StatusEvent.info,
            ));
          }

        case 'unmounted':
          if (await _isMounted()) {
            await _umount();
            emitEvent(CompletedEvent(
              moduleId: id,
              message: 'Mount $path unmounted',
            ));
          } else {
            emitEvent(StatusUpdateEvent(
              moduleId: id,
              message: 'Mount $path is already unmounted',
              level: StatusEvent.info,
            ));
          }

        case 'remounted':
          if (await _isMounted()) {
            await _umount();
          }
          await _mount();
          emitEvent(CompletedEvent(
            moduleId: id,
            message: 'Mount $path remounted',
          ));

        default:
          throw ActionFailedException(
            'Unknown state: $state. '
            'Use: present, absent, mounted, unmounted, remounted',
            moduleId: id,
          );
      }

      status = 'completed';
    } catch (e) {
      if (e is ActionFailedException) rethrow;
      throw ActionFailedException('mount block failed: $e', moduleId: id);
    }
  }

  @override
  Future<void> rollback() async {}
}

class _LinuxMountBlock extends MountBlock {
  _LinuxMountBlock() : super._();
}

class _MacOSMountBlock extends MountBlock {
  _MacOSMountBlock() : super._();
}

class _FreeBSDMountBlock extends MountBlock {
  _FreeBSDMountBlock() : super._();
}

class _UnsupportedMountBlock extends MountBlock {
  _UnsupportedMountBlock(this._facts) : super._();

  final OsFacts _facts;

  @override
  Future<void> execute() async {
    throw UnsupportedError(
      'Mount is not supported on ${_facts.os.name}. '
      'Currently supported: Linux, macOS, FreeBSD.',
    );
  }

  @override
  Future<void> rollback() async {}
}
