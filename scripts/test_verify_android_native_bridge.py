from pathlib import Path
import hashlib
import struct
import tempfile
import unittest
from unittest.mock import patch
import warnings
import zipfile

import verify_android_native_bridge as verifier


def elf(abi, alignment=16384):
    elf_class, machine = verifier.ABIS[abi]
    data = bytearray(120)
    data[:7] = b"\x7fELF" + bytes((elf_class, 1, 1))
    struct.pack_into("<HH", data, 16, 3, machine)
    if elf_class == 2:
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 1)
        struct.pack_into("<Q", data, 112, alignment)
    else:
        struct.pack_into("<I", data, 28, 64)
        struct.pack_into("<HH", data, 42, 32, 1)
        struct.pack_into("<I", data, 92, 4096)
    struct.pack_into("<I", data, 64, 1)
    return bytes(data)


class AndroidNativePayloadTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.apk = Path(self.directory.name) / "synthetic.apk"
        self.entries = {f"lib/{abi}/{library}": elf(abi)
                        for abi in verifier.ABIS for library in ("libflutter.so", verifier.BRIDGE, verifier.ONNX_RUNTIME)}
        # These are structural fixture bytes, never executable runtime evidence.
        fixture_hashes = {abi: hashlib.sha256(elf(abi)).hexdigest() for abi in verifier.ABIS}
        replacement = patch.object(verifier, "runtime_hashes", return_value=fixture_hashes)
        replacement.start()
        self.addCleanup(replacement.stop)

    def write(self):
        with zipfile.ZipFile(self.apk, "w") as archive:
            for name, contents in self.entries.items():
                archive.writestr(name, contents)

    def test_synthetic_payload_structure_acceptance_is_scoped(self):
        self.write()
        result = verifier.verify(self.apk)
        self.assertEqual(result["abis"], sorted(verifier.ABIS))
        self.assertIn("not installed-wallet acceptance", result["scope"])

    def test_missing_bridge_or_flutter_abi_is_rejected(self):
        for name in list(self.entries):
            contents = self.entries.pop(name)
            self.write()
            with self.subTest(name=name), self.assertRaises(ValueError):
                verifier.verify(self.apk)
            self.entries[name] = contents

    def test_wrong_machine_and_non_elf_payloads_are_rejected(self):
        for payload in (elf("armeabi-v7a"), b"not a native library"):
            self.entries[f"lib/x86_64/{verifier.BRIDGE}"] = payload
            self.write()
            with self.assertRaisesRegex(ValueError, "invalid native ELF"):
                verifier.verify(self.apk)

    def test_64bit_4kb_alignment_is_rejected_for_every_library(self):
        self.entries["lib/arm64-v8a/libunrelated.so"] = elf("arm64-v8a", alignment=4096)
        self.write()
        with self.assertRaisesRegex(ValueError, "16KB"):
            verifier.verify(self.apk)

    def test_duplicate_and_unexpected_native_entries_are_rejected(self):
        self.write()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.apk, "a") as archive:
                archive.writestr(f"lib/x86_64/{verifier.BRIDGE}", elf("x86_64"))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            verifier.verify(self.apk)
        self.entries["lib/other/libextra.so"] = elf("x86_64")
        self.write()
        with self.assertRaisesRegex(ValueError, "unexpected"):
            verifier.verify(self.apk)

    def test_structurally_valid_runtime_substitution_is_rejected(self):
        native = bytearray(elf("arm64-v8a"))
        native.extend(b"substituted runtime")
        self.entries[f"lib/arm64-v8a/{verifier.ONNX_RUNTIME}"] = native
        self.write()
        with self.assertRaisesRegex(ValueError, "runtime checksum"):
            verifier.verify(self.apk)


if __name__ == "__main__":
    unittest.main()
