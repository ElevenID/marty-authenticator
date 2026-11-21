import 'package:build_tool/src/cargo.dart';
import 'package:test/test.dart';

final _cargoToml = """
[workspace]

[profile.release]
lto = true
panic = "abort"
opt-level = "z"
# strip = "symbols"

[package]
name = "super_native_extensions"
version = "0.1.0"
edition = "2021"
resolver = "2"

[lib]
crate-type = ["cdylib", "staticlib"]
""";

void main() {
  test('hyphenated package uses normalized Cargo library name', () {
    final info = CrateInfo.parseManifest(
      '[package]\nname = "marty-authenticator-bridge"\n',
    );
    expect(info.packageName, 'marty-authenticator-bridge');
    expect(info.libraryName, 'marty_authenticator_bridge');
  });

  test('explicit lib.name is independent of package name', () {
    final info = CrateInfo.parseManifest(
      '[package]\nname = "marty-authenticator-bridge"\n[lib]\nname = "qualified_bridge"\n',
    );
    expect(info.libraryName, 'qualified_bridge');
  });

  test('empty or non-string explicit library name is rejected', () {
    for (final name in ['""', '42']) {
      expect(
        () => CrateInfo.parseManifest(
          '[package]\nname = "bridge"\n[lib]\nname = $name\n',
        ),
        throwsA(isA<ManifestException>()),
      );
    }
  });

  test('parseCargoToml', () {
    final info = CrateInfo.parseManifest(_cargoToml);
    expect(info.packageName, 'super_native_extensions');
  });
}
