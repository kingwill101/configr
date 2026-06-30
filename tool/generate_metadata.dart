// Generates LuaLS metadata stubs for the Configr Lua plugin API.
//
// Usage:
//   dart run tool/generate_metadata.dart [--no-stdlib] [--output-dir doc/api]
//
// Outputs:
//   - doc/api/configr.html   (standalone HTML reference)
//   - doc/api/configr.json   (JSON manifest for editor tooling)
//   - doc/api/configr.lua    (LuaLS annotation stubs for `luarc.json` library)
import 'package:configr/src/utils/event_bus.dart';
import 'package:file/file.dart';
import 'package:i3config/i3config_v2.dart' as i3;
import 'package:lualike/docs.dart';
import 'package:lualike/lualike.dart';
import 'package:lualike/src/docs/metadata_generator.dart';

import 'package:configr/src/lua/fixture_assertion_library.dart';
import 'package:configr/src/plugins/lua_library.dart';

void main(List<String> args) async {
  final outputDir = _parseArg(args, '--output-dir') ?? 'doc/api';
  final includeStdlib = !args.contains('--no-stdlib');

  final lua = LuaLike();

  // Register the ConfigrLibrary with a minimal stub host so the library can
  // be initialized and its documentation metadata collected.
  lua.vm.libraryRegistry.register(ConfigrLibrary(_StubLuaPluginHost()));

  // Register the fixture assertion library for test documentation.
  lua.vm.libraryRegistry.register(
    FixtureAssertionLibrary(_StubFileSystem(), StringBuffer()),
  );

  print('Generating Lua API metadata → $outputDir');
  print('Include stdlib: $includeStdlib');

  await generateMetadata(
    lua,
    outputDir: outputDir,
    formats: {MetadataFormat.html, MetadataFormat.json, MetadataFormat.luals},
    includeStdlib: includeStdlib,
    packageName: 'configr',
    pageOptions: const DocPageOptions(
      title: 'Configr Lua Plugin API',
      brandName: 'Configr',
      homeLabel: 'Configr Docs',
    ),
  );

  print('Done — files written to $outputDir');
  print('');
  print('For LuaLS, add to your .luarc.json:');
  print('  "workspace.library": ["$outputDir/configr.lua"]');
}

String? _parseArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}

// Minimal [LuaPluginHost] stub used when generating metadata at build time.
//
// None of the library functions are actually *called* during metadata
// generation — only their [FunctionDoc] descriptions are read — so this stub
// only needs to satisfy the type contract.
class _StubLuaPluginHost implements LuaPluginHost {
  @override
  i3.Context? get currentContext => null;

  @override
  EventBus? get eventBus => null;

  @override
  FileSystem get fileSystem =>
      throw UnsupportedError('Not available during metadata generation');

  @override
  void registerBlockInPlugin(String blockType, Object? callbacks) {
    // Not called during metadata generation.
  }

  @override
  ProcessBackend? get processBackend => throw UnimplementedError();
}

/// Stub [FileSystem] used when generating metadata for [FixtureAssertionLibrary].
class _StubFileSystem implements FileSystem {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Not available during metadata generation');
}
