"""Check built APK native payloads, not installed-wallet behavior."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile


ABIS = {"armeabi-v7a": (1, 40), "arm64-v8a": (2, 183), "x86_64": (2, 62)}
BRIDGE = "libmarty_authenticator_bridge.so"


def check_elf(stream, abi: str) -> None:
    header = stream.read(64)
    elf_class, machine = ABIS[abi]
    if (len(header) < 64 or header[:4] != b"\x7fELF"
            or header[4:7] != bytes((elf_class, 1, 1))
            or struct.unpack_from("<HH", header, 16) != (3, machine)):
        raise ValueError(f"invalid native ELF for {abi}")
    if elf_class == 2:
        offset = struct.unpack_from("<Q", header, 32)[0]
        entry_size, count = struct.unpack_from("<HH", header, 54)
        expected_size, align_offset = 56, 48
    else:
        offset = struct.unpack_from("<I", header, 28)[0]
        entry_size, count = struct.unpack_from("<HH", header, 42)
        expected_size, align_offset = 32, 28
    if entry_size != expected_size or not 0 < count <= 1024 or not 52 <= offset <= 65536:
        raise ValueError(f"invalid native program headers for {abi}")
    stream.seek(offset)
    loads = 0
    for _ in range(count):
        entry = stream.read(entry_size)
        if len(entry) != entry_size:
            raise ValueError(f"truncated native program header for {abi}")
        if struct.unpack_from("<I", entry)[0] != 1:  # PT_LOAD
            continue
        loads += 1
        if elf_class == 2:
            alignment = struct.unpack_from("<Q", entry, align_offset)[0]
            if alignment < 16384 or alignment & (alignment - 1):
                raise ValueError(f"64-bit native library lacks 16KB LOAD alignment for {abi}")
    if not loads:
        raise ValueError(f"native ELF has no LOAD segments for {abi}")


def verify(apk: Path) -> dict:
    with zipfile.ZipFile(apk) as archive:
        native = [entry for entry in archive.infolist()
                  if entry.filename.startswith("lib/") and entry.filename.endswith(".so")]
        names = [entry.filename for entry in native]
        if len(names) != len(set(names)):
            raise ValueError("duplicate APK native library entries")
        flutter_abis = {abi for abi in ABIS if f"lib/{abi}/libflutter.so" in names}
        bridge_abis = {abi for abi in ABIS if f"lib/{abi}/{BRIDGE}" in names}
        if flutter_abis != set(ABIS) or bridge_abis != flutter_abis:
            raise ValueError("APK must bundle Flutter and the native bridge for all three configured ABIs")
        for entry in native:
            parts = entry.filename.split("/")
            if len(parts) != 3 or parts[1] not in ABIS:
                raise ValueError("unexpected APK native library path or ABI")
            with archive.open(entry) as stream:
                check_elf(stream, parts[1])
    digest = hashlib.file_digest
    with apk.open("rb") as stream:
        sha256 = digest(stream, "sha256").hexdigest()
    return {"apk": apk.name, "sha256": sha256, "abis": sorted(bridge_abis),
            "nativeLibrariesChecked": len(native), "scope": "packaged ELF/ABI structure, not installed-wallet acceptance"}


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: verify_android_native_bridge.py APK [APK ...]")
    for argument in sys.argv[1:]:
        print(json.dumps(verify(Path(argument)), sort_keys=True))


if __name__ == "__main__":
    main()
