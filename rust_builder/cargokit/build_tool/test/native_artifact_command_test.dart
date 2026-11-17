import 'dart:io';

import 'package:build_tool/src/artifacts_provider.dart';
import 'package:build_tool/src/builder.dart';
import 'package:build_tool/src/cargo.dart';
import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/target.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test(
    'native Cargo fixture exercises Android dylib selection and retained static output',
    () {
      final temporary = Directory.systemTemp.createTempSync(
        'cargo artifact policy ',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      const manifest = '''
[package]
name = "artifact-policy-fixture"
version = "0.1.0"
edition = "2021"
[lib]
name = "fixture_api"
crate-type = ["cdylib", "staticlib"]
''';
      File(path.join(temporary.path, 'Cargo.toml')).writeAsStringSync(manifest);
      File(path.join(temporary.path, 'Cargo.lock')).writeAsStringSync('''
version = 4
[[package]]
name = "artifact-policy-fixture"
version = "0.1.0"
''');
      Directory(path.join(temporary.path, 'src')).createSync();
      File(path.join(temporary.path, 'src', 'lib.rs')).writeAsStringSync(
        '#[no_mangle]\npub extern "C" fn fixture_value() -> i32 { 42 }\n',
      );
      final version = Process.runSync('rustc', ['-vV']);
      expect(version.exitCode, 0, reason: '${version.stderr}');
      final host = RegExp(
        r'^host: (.+)$',
        multiLine: true,
      ).firstMatch('${version.stdout}')!.group(1)!;
      final nativeTarget = Target.forRustTriple(host)!;
      for (final androidOutputPolicy in [false, true]) {
        final output = path.join(
          temporary.path,
          androidOutputPolicy ? 'dylib' : 'ordinary',
        );
        // This is a native-host command/output contract fixture, not an Android
        // cross-build. Only the Android output-policy marker is adapted here.
        final target = androidOutputPolicy
            ? Target(rust: host, android: 'native-command-fixture')
            : nativeTarget;
        final environment = BuildEnvironment(
          configuration: BuildConfiguration.debug,
          crateOptions: CargokitCrateOptions(
            cargo: {
              BuildConfiguration.debug: CargoBuildOptions(
                toolchain: Toolchain.stable,
                flags: ['--locked', '--offline'],
              ),
            },
          ),
          targetTempDir: output,
          manifestDir: temporary.path,
          crateInfo: CrateInfo.parseManifest(manifest),
          isAndroid: androidOutputPolicy,
        );
        final args = RustBuilder(
          target: target,
          environment: environment,
        ).cargoArguments;
        final result = Process.runSync('cargo', args);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final artifacts = Directory(path.join(output, host, 'debug'));
        final dynamicNames = getArtifactNames(
          target: nativeTarget,
          libraryName: 'fixture_api',
          remote: false,
          aritifactType: AritifactType.dylib,
        );
        final staticNames = getArtifactNames(
          target: nativeTarget,
          libraryName: 'fixture_api',
          remote: false,
          aritifactType: AritifactType.staticlib,
        );
        expect(
          dynamicNames.any(
            (name) => File(path.join(artifacts.path, name)).existsSync(),
          ),
          isTrue,
        );
        expect(
          staticNames.any(
            (name) => File(path.join(artifacts.path, name)).existsSync(),
          ),
          !androidOutputPolicy,
        );
        expect(
          File(path.join(temporary.path, 'Cargo.lock')).readAsStringSync(),
          '''
version = 4
[[package]]
name = "artifact-policy-fixture"
version = "0.1.0"
''',
        );
      }
    },
  );
}
