"""Structural/provenance tests; synthetic ELF bytes are not native execution."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import android_native_artifacts as artifacts
import verify_android_native_bridge as apk_verifier
from test_verify_android_native_bridge import elf


class NativeArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundles = self.root / "downloaded"
        self.bundles.mkdir()
        self.tool = self.root / "llvm-strip"
        self.tool.write_text("#!/usr/bin/env python3\nimport pathlib,sys\n"
                             "assert sys.argv[1:3] == ['--strip-unneeded','-o']\n"
                             "pathlib.Path(sys.argv[3]).write_bytes("
                             "pathlib.Path(sys.argv[4]).read_bytes().removesuffix(b'DEBUG_ONLY'))\n")
        self.tool.chmod(0o755)
        self.context = {
            "repository": artifacts.REPOSITORY, "commit": "a" * 40, "tree": "b" * 40,
            "runId": "100", "runAttempt": "2", "inputs": {"rust/Cargo.lock": "c" * 64},
            "build": {"mode": "debug", "rust": artifacts.RUST, "flutter": artifacts.FLUTTER,
                      "ndk": artifacts.NDK, "devDebug": "0", "crateType": "cdylib",
                      "cargoFlags": ["--locked", "--offline"]},
        }
        hashes = {abi: hashlib.sha256(elf(abi)).hexdigest() for abi in artifacts.TARGETS}
        for module in (artifacts, apk_verifier):
            replacement = patch.object(module, "runtime_hashes", return_value=hashes)
            replacement.start()
            self.addCleanup(replacement.stop)
        for abi in artifacts.TARGETS:
            source = self.root / f"producer-{abi}"
            (source / abi).mkdir(parents=True)
            (source / abi / artifacts.BRIDGE).write_bytes(elf(abi) + b"DEBUG_ONLY")
            (source / abi / artifacts.ONNX_RUNTIME).write_bytes(elf(abi))
            artifacts.export_artifact(source, self.bundle(abi), abi, self.context, self.tool)

    def bundle(self, abi):
        return self.bundles / artifacts.artifact_name(self.context, abi)

    def validate(self):
        return artifacts.validate_artifacts(self.bundles, self.context, self.tool)

    def write_manifest(self, manifest, abi="arm64-v8a"):
        (self.bundle(abi) / "manifest.json").write_text(json.dumps(manifest))

    def manifest(self, abi="arm64-v8a"):
        return json.loads((self.bundle(abi) / "manifest.json").read_text())

    def make_apk(self, *, raw_bridge=False, tamper=False):
        apk = self.root / "fixture.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            for abi in artifacts.TARGETS:
                for name in ("libflutter.so", artifacts.BRIDGE, artifacts.ONNX_RUNTIME):
                    data = elf(abi)
                    if name == artifacts.BRIDGE and raw_bridge:
                        data += b"DEBUG_ONLY"
                    if name == artifacts.BRIDGE and abi == "arm64-v8a" and tamper:
                        data += b"substituted native implementation"
                    archive.writestr(f"lib/{abi}/{name}", data)
        return apk

    def test_three_source_outputs_stage_and_bind_actual_apk_bytes(self):
        output = self.root / "jniLibs" / "debug"
        manifests = artifacts.stage_artifacts(self.bundles, output, self.context, self.tool)
        self.assertEqual(set(manifests), set(artifacts.TARGETS))
        for abi in artifacts.TARGETS:
            self.assertEqual((output / abi / artifacts.BRIDGE).read_bytes(), elf(abi) + b"DEBUG_ONLY")
            self.assertNotEqual(manifests[abi]["libraries"][artifacts.BRIDGE]["sha256"],
                                manifests[abi]["libraries"][artifacts.BRIDGE]["apkSha256"])
        result = apk_verifier.verify(self.make_apk(), manifests)
        self.assertEqual(result["nativeSource"], self.context)
        self.assertEqual(result["abis"], sorted(artifacts.TARGETS))

    def test_current_source_tree_run_attempt_and_inputs_are_required(self):
        original = self.manifest()
        mutations = (("commit", "d" * 40), ("tree", "e" * 40), ("runId", "99"),
                     ("runAttempt", "1"), ("repository", "foreign/repo"),
                     ("inputs", {"rust/Cargo.lock": "f" * 64}), ("build", {}))
        for key, value in mutations:
            modified = deepcopy(original)
            modified["context"][key] = value
            self.write_manifest(modified)
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "provenance"):
                self.validate()
        self.write_manifest(original)
        self.validate()

    def test_missing_extra_and_stale_artifact_directories_are_rejected(self):
        current = self.bundle("x86_64")
        moved = self.root / "held"
        current.rename(moved)
        with self.assertRaisesRegex(ValueError, "exactly three"):
            self.validate()
        moved.rename(current)
        extra = self.bundles / "wallet-native-stale-attempt-x86_64"
        extra.mkdir()
        with self.assertRaisesRegex(ValueError, "exactly three"):
            self.validate()

    def test_duplicate_json_and_unknown_metadata_are_rejected(self):
        target = self.bundle("arm64-v8a") / "manifest.json"
        original = target.read_text()
        target.write_text('{"schema":"duplicate",' + original[1:])
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            self.validate()
        value = json.loads(original)
        value["skipVerification"] = True
        self.write_manifest(value)
        with self.assertRaisesRegex(ValueError, "manifest shape"):
            self.validate()

    def test_source_or_expected_packaged_bytes_cannot_be_substituted(self):
        bridge = self.bundle("arm64-v8a") / artifacts.BRIDGE
        original = bridge.read_bytes()
        bridge.write_bytes(original + b"changed")
        with self.assertRaisesRegex(ValueError, "bytes or stripped"):
            self.validate()
        bridge.write_bytes(original)
        manifest = self.manifest()
        manifest["libraries"][artifacts.BRIDGE]["apkSha256"] = "0" * 64
        self.write_manifest(manifest)
        with self.assertRaisesRegex(ValueError, "bytes or stripped"):
            self.validate()

    def test_wrong_machine_runtime_and_strip_tool_are_rejected(self):
        bridge = self.bundle("arm64-v8a") / artifacts.BRIDGE
        original = bridge.read_bytes()
        bridge.write_bytes(elf("x86_64"))
        with self.assertRaisesRegex(ValueError, "invalid native ELF"):
            self.validate()
        bridge.write_bytes(original)
        runtime = self.bundle("arm64-v8a") / artifacts.ONNX_RUNTIME
        runtime.write_bytes(elf("arm64-v8a") + b"foreign runtime")
        with self.assertRaisesRegex(ValueError, "runtime checksum"):
            self.validate()
        runtime.write_bytes(elf("arm64-v8a"))
        self.tool.write_text(self.tool.read_text() + "# different tool\n")
        with self.assertRaisesRegex(ValueError, "provenance"):
            self.validate()

    def test_symlink_and_extra_library_payloads_are_rejected(self):
        bridge = self.bundle("arm64-v8a") / artifacts.BRIDGE
        saved = self.root / "external.so"
        bridge.rename(saved)
        bridge.symlink_to(saved)
        with self.assertRaisesRegex(ValueError, "regular file"):
            self.validate()
        bridge.unlink()
        saved.rename(bridge)
        (self.bundle("arm64-v8a") / "libextra.so").write_bytes(elf("arm64-v8a"))
        with self.assertRaisesRegex(ValueError, "unexpected or missing"):
            self.validate()

    def test_existing_stage_is_preserved_and_partial_copy_is_removed(self):
        output = self.root / "existing-output"
        output.mkdir()
        marker = output / "owned-existing-file"
        marker.write_text("preserve")
        with self.assertRaisesRegex(ValueError, "new output directory"):
            artifacts.stage_artifacts(self.bundles, output, self.context, self.tool)
        self.assertEqual(marker.read_text(), "preserve")
        fresh = self.root / "fresh-output"
        with patch.object(artifacts.shutil, "copyfile", side_effect=OSError("copy failed")):
            with self.assertRaisesRegex(OSError, "copy failed"):
                artifacts.stage_artifacts(self.bundles, fresh, self.context, self.tool)
        self.assertFalse(fresh.exists())

    def test_apk_must_contain_exact_stripped_source_output(self):
        manifests = self.validate()
        for raw, tamper in ((True, False), (False, True)):
            with self.subTest(raw=raw, tamper=tamper), self.assertRaisesRegex(ValueError, "source-built artifact"):
                apk_verifier.verify(self.make_apk(raw_bridge=raw, tamper=tamper), manifests)

    def test_boolean_size_and_duplicate_library_json_are_rejected(self):
        original = self.manifest()
        modified = deepcopy(original)
        modified["libraries"][artifacts.BRIDGE]["bytes"] = True
        self.write_manifest(modified)
        with self.assertRaisesRegex(ValueError, "size or digest"):
            self.validate()
        target = self.bundle("arm64-v8a") / "manifest.json"
        text = json.dumps(original)
        target.write_text(text.replace('"apkBytes":', '"apkBytes": 1, "apkBytes":', 1))
        with self.assertRaisesRegex(ValueError, "duplicate JSON"):
            self.validate()


class ActualContextTests(unittest.TestCase):
    def test_context_binds_real_git_tree_and_rejects_dirty_or_wrong_checkout(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in artifacts.INPUTS:
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("source fixture\n")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c",
                            "user.email=fixture@example.invalid", "commit", "-qm", "fixture"], check=True)
            commit = artifacts.git(root, "rev-parse", "HEAD")
            env = {"GITHUB_ACTIONS": "true", "GITHUB_REPOSITORY": artifacts.REPOSITORY,
                   "GITHUB_SHA": commit, "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "2",
                   "CARGO_PROFILE_DEV_DEBUG": "0"}
            context = artifacts.current_context(root, env)
            self.assertEqual(context["tree"], artifacts.git(root, "rev-parse", "HEAD^{tree}"))
            for key, value in (("GITHUB_SHA", "0" * 40), ("GITHUB_RUN_ATTEMPT", "0"),
                               ("GITHUB_REPOSITORY", "foreign/repo"), ("CARGO_PROFILE_DEV_DEBUG", "1")):
                with self.subTest(key=key), self.assertRaises(ValueError):
                    artifacts.current_context(root, dict(env, **{key: value}))
            (root / "rust/Cargo.lock").write_text("changed")
            with self.assertRaises(subprocess.CalledProcessError):
                artifacts.current_context(root, env)

    def test_strip_tool_preserves_alias_and_rejects_escape_or_wrong_ndk(self):
        with tempfile.TemporaryDirectory() as temp:
            sdk = Path(temp)
            ndk = sdk / "ndk" / artifacts.NDK
            binaries = ndk / "toolchains/llvm/prebuilt/linux-x86_64/bin"
            binaries.mkdir(parents=True)
            (ndk / "source.properties").write_text(f"Pkg.Revision = {artifacts.NDK}\n")
            implementation = binaries / "llvm-objcopy"
            implementation.write_text("test executable")
            alias = binaries / "llvm-strip"
            alias.symlink_to(implementation)
            env = {"ANDROID_SDK_ROOT": str(sdk)}
            self.assertEqual(artifacts.strip_tool(env), alias)
            alias.unlink()
            outside = sdk / "foreign-tool"
            outside.write_text("foreign")
            alias.symlink_to(outside)
            with self.assertRaisesRegex(ValueError, "escaped"):
                artifacts.strip_tool(env)
            (ndk / "source.properties").write_text("Pkg.Revision = 0.0.0\n")
            with self.assertRaisesRegex(ValueError, "revision"):
                artifacts.strip_tool(env)


if __name__ == "__main__":
    unittest.main()
