import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:toml/toml.dart';

import 'target.dart';

/// Selects the same pinned native runtime for Rust linking and JNI packaging.
/// This validates dependency bytes; it does not qualify inference or devices.
class AndroidOnnxRuntime {
  AndroidOnnxRuntime._(this.library);

  final File library;

  static const _elfTypes = {
    'armeabi-v7a': (1, 40),
    'arm64-v8a': (2, 183),
    'x86': (1, 3),
    'x86_64': (2, 62),
  };

  static AndroidOnnxRuntime load({
    required String manifestDir,
    required String runtimeDir,
    required Target target,
    required int minSdkVersion,
  }) {
    Never refused() =>
        throw StateError('Pinned Android ONNX runtime is invalid');
    final abi = target.android;
    if (!_elfTypes.containsKey(abi)) refused();
    final pinFile = File(
      path.join(
        manifestDir,
        '..',
        'rust_builder',
        'android',
        'onnxruntime-android.lock.json',
      ),
    );
    final pin = jsonDecode(pinFile.readAsStringSync());
    if (pin is! Map<String, dynamic> ||
        pin['schema'] != 1 ||
        pin['version'] != '1.24.2' ||
        pin['ortSysVersion'] != '2.0.0-rc.12' ||
        pin['androidMinApi'] != 24 ||
        minSdkVersion < 24) {
      refused();
    }
    final packages = TomlDocument.parse(
      File(path.join(manifestDir, 'Cargo.lock')).readAsStringSync(),
    ).toMap()['package'];
    if (packages is! List) refused();
    final ort = packages
        .whereType<Map>()
        .where((p) => p['name'] == 'ort-sys')
        .toList();
    if (ort.length != 1 || ort.single['version'] != pin['ortSysVersion']) {
      refused();
    }
    final libraries = pin['libraries'];
    if (libraries is! Map ||
        libraries.length != _elfTypes.length ||
        !_elfTypes.keys.every(libraries.containsKey)) {
      refused();
    }
    final expected = libraries[abi];
    if (expected is! Map ||
        expected['bytes'] is! int ||
        expected['bytes'] < 64 ||
        expected['bytes'] > 64 * 1024 * 1024 ||
        expected['sha256'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expected['sha256'])) {
      refused();
    }
    final library = File(path.join(runtimeDir, abi!, 'libonnxruntime.so'));
    if (FileSystemEntity.typeSync(library.path, followLinks: false) !=
            FileSystemEntityType.file ||
        library.lengthSync() != expected['bytes']) {
      refused();
    }
    final bytes = library.readAsBytesSync();
    if (sha256.convert(bytes).toString() != expected['sha256']) refused();
    final data = ByteData.sublistView(bytes);
    final type = _elfTypes[abi]!;
    if (bytes[0] != 0x7f ||
        bytes[1] != 0x45 ||
        bytes[2] != 0x4c ||
        bytes[3] != 0x46 ||
        bytes[4] != type.$1 ||
        bytes[5] != 1 ||
        bytes[6] != 1 ||
        data.getUint16(16, Endian.little) != 3 ||
        data.getUint16(18, Endian.little) != type.$2) {
      refused();
    }
    return AndroidOnnxRuntime._(library);
  }

  Map<String, String> get environment => {
    // ort-sys checks PATH before LOCATION. Override both aliases so an inherited
    // host runtime cannot take precedence over the verified Android target.
    'ORT_LIB_PATH': library.parent.absolute.path,
    'ORT_LIB_LOCATION': library.parent.absolute.path,
    'ORT_PREFER_DYNAMIC_LINK': '1',
    'ORT_SKIP_DOWNLOAD': '1',
  };
}
