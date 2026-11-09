import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    if (code.targetOS != OS.windows && code.targetOS != OS.android) return;
    await FlutterRustBridgeNativeAssetsBuilder(
      assetName: 'agent/bridge/generated/frb_generated.io.dart',
      cratePath: 'rust',
      extraCargoBuildArgs: const ['--locked'],
      extraCargoEnvironmentVariables: _androidCompilerEnvironment(code),
    ).run(input: input, output: output);
  });
}

Map<String, String> _androidCompilerEnvironment(CodeConfig code) {
  if (code.targetOS != OS.android) return const {};
  final triple = switch (code.targetArchitecture) {
    Architecture.arm => 'armv7-linux-androideabi',
    Architecture.arm64 => 'aarch64-linux-android',
    Architecture.x64 => 'x86_64-linux-android',
    _ => throw UnsupportedError('Unsupported Android architecture.'),
  };
  final ndkTriple = triple == 'armv7-linux-androideabi'
      ? 'armv7a-linux-androideabi'
      : triple;
  final compilerDirectory = path.dirname(
    path.fromUri(code.cCompiler!.compiler),
  );
  final suffix = Platform.isWindows ? '.cmd' : '';
  final prefix = '$ndkTriple${code.android.targetNdkApi}';
  final clang = path.join(compilerDirectory, '$prefix-clang$suffix');
  final clangPlusPlus = path.join(compilerDirectory, '$prefix-clang++$suffix');
  final environmentTriple = triple.replaceAll('-', '_');
  // native_toolchain_rust 1.0.7 defaults to API 35; use Flutter's minimum API.
  return {
    'CC_$environmentTriple': clang,
    'CXX_$environmentTriple': clangPlusPlus,
    'CARGO_TARGET_${environmentTriple.toUpperCase()}_LINKER': clang,
  };
}
