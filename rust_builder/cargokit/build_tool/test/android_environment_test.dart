import 'dart:io';

import 'package:build_tool/src/android_environment.dart';
import 'package:build_tool/src/target.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  const targets = {
    'armv7-linux-androideabi': (
      'armv7a-linux-androideabi',
      'arm-linux-androideabi',
    ),
    'aarch64-linux-android': ('aarch64-linux-android', 'aarch64-linux-android'),
    'x86_64-linux-android': ('x86_64-linux-android', 'x86_64-linux-android'),
  };
  for (final entry in targets.entries) {
    test(
      'Android headers and API follow the selected ${entry.key} target',
      () async {
        final temporary = Directory.systemTemp.createTempSync(
          'ndk header fixture ',
        );
        addTearDown(() => temporary.deleteSync(recursive: true));
        final host = Platform.isMacOS
            ? 'darwin-x86_64'
            : (Platform.isLinux ? 'linux-x86_64' : 'windows-x86_64');
        final toolchain = path.join(
          temporary.path,
          'ndk',
          '28.2.13676358',
          'toolchains',
          'llvm',
          'prebuilt',
          host,
        );
        final bin = Directory(path.join(toolchain, 'bin'))
          ..createSync(recursive: true);
        // Structural fixture only: no fake compiler is executed and no actual
        // Android cross-build is claimed by these tests.
        File(path.join(bin.path, 'llvm-ar')).writeAsStringSync('');
        final environment = await AndroidEnvironment(
          sdkPath: temporary.path,
          ndkVersion: '28.2.13676358',
          minSdkVersion: 26,
          targetTempDir: path.join(temporary.path, 'build'),
          target: Target.forRustTriple(entry.key)!,
        ).buildEnvironment();
        final args =
            environment['BINDGEN_EXTRA_CLANG_ARGS_${entry.key.replaceAll('-', '_')}']!;
        final sysroot = path.join(toolchain, 'sysroot').replaceAll('\\', '/');
        expect(
          args,
          '--target=${entry.value.$1}26 '
          '--sysroot="$sysroot" -I"$sysroot/usr/include/${entry.value.$2}"',
        );
        final tools = bin.path.replaceAll('\\', '/');
        final extension = Platform.isWindows ? '.exe' : '';
        expect(environment['CLANG_PATH'], '$tools/clang$extension');
        expect(environment['CC_${entry.key}'], '$tools/clang$extension');
        expect(environment['CXX_${entry.key}'], '$tools/clang++$extension');
        expect(environment['AR_${entry.key}'], '$tools/llvm-ar');
        expect(
          environment['RANLIB_${entry.key}'],
          '$tools/llvm-ranlib$extension',
        );
        expect(
          environment['CFLAGS_${entry.key}'],
          '--target=${entry.value.$1}26',
        );
        expect(environment.containsKey('BINDGEN_EXTRA_CLANG_ARGS'), isFalse);
        expect(
          environment.keys.where(
            (key) => key.startsWith('BINDGEN_EXTRA_CLANG_ARGS_'),
          ),
          hasLength(1),
        );
      },
    );
  }
}
