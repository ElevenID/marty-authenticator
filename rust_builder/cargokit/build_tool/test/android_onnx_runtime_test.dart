import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/src/android_onnx_runtime.dart';
import 'package:build_tool/src/target.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory temporary;
  late Directory manifest;
  late Directory runtime;
  late File pinFile;
  late Map<String, dynamic> pin;
  const types = {
    'armeabi-v7a': (1, 40),
    'arm64-v8a': (2, 183),
    'x86': (1, 3),
    'x86_64': (2, 62),
  };

  setUp(() {
    temporary = Directory.systemTemp.createTempSync('onnx fixture ');
    manifest = Directory(path.join(temporary.path, 'rust'))..createSync();
    runtime = Directory(path.join(temporary.path, 'runtime'))..createSync();
    pinFile = File(
      path.join(
        temporary.path,
        'rust_builder',
        'android',
        'onnxruntime-android.lock.json',
      ),
    );
    pinFile.parent.createSync(recursive: true);
    pin = {
      'schema': 1,
      'version': '1.24.2',
      'ortSysVersion': '2.0.0-rc.12',
      'androidMinApi': 24,
      'libraries': <String, dynamic>{},
    };
    for (final entry in types.entries) {
      // Structural fixture only; no fake library is loaded or linked.
      final bytes = Uint8List(64);
      bytes.setRange(0, 7, [0x7f, 0x45, 0x4c, 0x46, entry.value.$1, 1, 1]);
      final data = ByteData.sublistView(bytes);
      data.setUint16(16, 3, Endian.little);
      data.setUint16(18, entry.value.$2, Endian.little);
      final library = File(
        path.join(runtime.path, entry.key, 'libonnxruntime.so'),
      );
      library.parent.createSync();
      library.writeAsBytesSync(bytes);
      pin['libraries'][entry.key] = {
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      };
    }
    pinFile.writeAsStringSync(jsonEncode(pin));
    File(path.join(manifest.path, 'Cargo.lock')).writeAsStringSync(
      'version = 4\n[[package]]\nname = "ort-sys"\nversion = "2.0.0-rc.12"\n',
    );
  });
  tearDown(() => temporary.deleteSync(recursive: true));

  AndroidOnnxRuntime load(String rust, {int api = 26}) =>
      AndroidOnnxRuntime.load(
        manifestDir: manifest.path,
        runtimeDir: runtime.path,
        target: Target.forRustTriple(rust)!,
        minSdkVersion: api,
      );

  test('each selected target owns both ORT aliases and dynamic linkage', () {
    for (final target in Target.androidTargets()) {
      final selected = load(target.rust);
      final directory = path.join(runtime.path, target.android!);
      expect(selected.environment['ORT_LIB_PATH'], directory);
      expect(selected.environment['ORT_LIB_LOCATION'], directory);
      expect(selected.environment['ORT_PREFER_DYNAMIC_LINK'], '1');
      expect(selected.environment['ORT_SKIP_DOWNLOAD'], '1');
    }
  });

  test('missing or substituted runtime never falls back to another ABI', () {
    final library = File(
      path.join(runtime.path, 'armeabi-v7a', 'libonnxruntime.so'),
    );
    library.writeAsStringSync('wrong runtime');
    expect(() => load('armv7-linux-androideabi'), throwsStateError);
    library.deleteSync();
    expect(() => load('armv7-linux-androideabi'), throwsStateError);
  });

  test('wrong machine is refused even when fixture digest matches', () {
    final wrong = File(
      path.join(runtime.path, 'arm64-v8a', 'libonnxruntime.so'),
    ).readAsBytesSync();
    File(
      path.join(runtime.path, 'armeabi-v7a', 'libonnxruntime.so'),
    ).writeAsBytesSync(wrong);
    pin['libraries']['armeabi-v7a']['sha256'] = sha256
        .convert(wrong)
        .toString();
    pinFile.writeAsStringSync(jsonEncode(pin));
    expect(() => load('armv7-linux-androideabi'), throwsStateError);
  });

  test(
    'runtime API floor and crate upgrade require deliberate qualification',
    () {
      expect(() => load('aarch64-linux-android', api: 23), throwsStateError);
      File(path.join(manifest.path, 'Cargo.lock')).writeAsStringSync(
        '[[package]]\nname = "ort-sys"\nversion = "2.0.0-rc.15"\n',
      );
      expect(() => load('aarch64-linux-android'), throwsStateError);
    },
  );

  test('symlink or incomplete lock cannot authorize a library', () {
    if (!Platform.isWindows) {
      final library = File(
        path.join(runtime.path, 'armeabi-v7a', 'libonnxruntime.so'),
      );
      final original = library.renameSync('${library.path}.original');
      Link(library.path).createSync(original.path);
      expect(() => load('armv7-linux-androideabi'), throwsStateError);
    }
    (pin['libraries'] as Map).remove('x86_64');
    pinFile.writeAsStringSync(jsonEncode(pin));
    expect(() => load('aarch64-linux-android'), throwsStateError);
  });
}
