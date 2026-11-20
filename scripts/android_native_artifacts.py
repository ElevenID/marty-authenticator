"""Bind CI-built Android native libraries to the current source and workflow run.

The producer is an actual Cargokit source-build task. This module transfers its
outputs between jobs in that same run; it never downloads a release binary or
changes the application's normal source-build path.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile

from verify_android_native_bridge import ABIS, BRIDGE, ONNX_RUNTIME, check_elf, runtime_hashes


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "marty.android-native-ci/v1"
REPOSITORY = "ElevenID/marty-authenticator"
NDK = "28.2.13676358"
RUST = "1.97.1"
FLUTTER = "3.44.6"
TARGETS = {
    "armeabi-v7a": ("android-arm", "armv7-linux-androideabi"),
    "arm64-v8a": ("android-arm64", "aarch64-linux-android"),
    "x86_64": ("android-x64", "x86_64-linux-android"),
}
INPUTS = (
    "rust/Cargo.toml", "rust/Cargo.lock", "rust/cargokit.yaml",
    "rust-toolchain.toml", "cargokit_options.yaml",
    "rust_builder/android/onnxruntime-android.lock.json",
    "rust_builder/cargokit/gradle/plugin.gradle",
    "android/app/build.gradle", "android/settings.gradle", "android/gradle.properties",
    "android/gradle/wrapper/gradle-wrapper.properties",
)
MAX_LIBRARY = 256 * 1024 * 1024
HASH = re.compile(r"[a-f0-9]{64}\Z")
COMMIT = re.compile(r"[a-f0-9]{40}\Z")


def digest(file: Path) -> str:
    with file.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def regular(file: Path, *, maximum: int = MAX_LIBRARY) -> None:
    mode = file.lstat().st_mode
    if not stat.S_ISREG(mode) or not 0 < file.stat().st_size <= maximum:
        raise ValueError(f"expected a bounded regular file: {file.name}")


def directory(path: Path) -> None:
    if not stat.S_ISDIR(path.lstat().st_mode):
        raise ValueError(f"expected a real directory: {path.name}")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def read_manifest(path: Path) -> dict:
    regular(path, maximum=64 * 1024)
    result = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    if not isinstance(result, dict):
        raise ValueError("native manifest must be an object")
    return result


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def current_context(root: Path = ROOT, environ=None) -> dict:
    env = os.environ if environ is None else environ
    if env.get("GITHUB_ACTIONS") != "true" or env.get("GITHUB_REPOSITORY") != REPOSITORY:
        raise ValueError("native transfer is limited to this repository's GitHub workflow")
    run, attempt = env.get("GITHUB_RUN_ID", ""), env.get("GITHUB_RUN_ATTEMPT", "")
    if not re.fullmatch(r"[1-9][0-9]*", run) or not re.fullmatch(r"[1-9][0-9]*", attempt):
        raise ValueError("missing workflow run identity")
    commit, tree = git(root, "rev-parse", "HEAD"), git(root, "rev-parse", "HEAD^{tree}")
    if not COMMIT.fullmatch(commit) or not COMMIT.fullmatch(tree) or commit != env.get("GITHUB_SHA"):
        raise ValueError("checkout must match this workflow's exact source commit")
    subprocess.run(["git", "-C", str(root), "diff", "--quiet", "HEAD", "--"], check=True)
    if env.get("CARGO_PROFILE_DEV_DEBUG") != "0":
        raise ValueError("native qualification requires the reviewed debug-information setting")
    return {
        "repository": REPOSITORY, "commit": commit, "tree": tree,
        "runId": run, "runAttempt": attempt,
        "inputs": {name: digest(root / name) for name in INPUTS},
        "build": {"mode": "debug", "rust": RUST, "flutter": FLUTTER,
                  "ndk": NDK, "devDebug": "0", "crateType": "cdylib",
                  "cargoFlags": ["--locked", "--offline"]},
    }


def strip_tool(environ=None) -> Path:
    env = os.environ if environ is None else environ
    sdk = env.get("ANDROID_SDK_ROOT") or env.get("ANDROID_HOME")
    if not sdk:
        raise ValueError("Android SDK is required to verify the pinned strip tool")
    ndk = Path(sdk) / "ndk" / NDK
    properties = (ndk / "source.properties").read_text(encoding="utf-8")
    revisions = re.findall(r"^Pkg\.Revision\s*=\s*(\S+)\s*$", properties, re.MULTILINE)
    if revisions != [NDK]:
        raise ValueError("Android NDK revision differs from the reviewed pin")
    tool = ndk / "toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    # NDK's executable may be a bundled llvm-objcopy symlink. Resolve only inside
    # the same immutable NDK installation, then hash the actual executable.
    resolved = tool.resolve(strict=True)
    if not resolved.is_relative_to(ndk.resolve(strict=True)):
        raise ValueError("Android strip tool escaped the pinned NDK")
    regular(resolved)
    # Preserve argv[0]: llvm-strip may share an executable with llvm-objcopy,
    # whose command-line mode is selected by the invoked alias.
    return tool


def library_record(file: Path, abi: str, tool: Path, scratch: Path) -> dict:
    regular(file)
    with file.open("rb") as stream:
        check_elf(stream, abi)
    record = {"bytes": file.stat().st_size, "sha256": digest(file)}
    if file.name == BRIDGE:
        stripped = scratch / f"{abi}-{BRIDGE}"
        subprocess.run([str(tool), "--strip-unneeded", "-o", str(stripped), str(file)],
                       check=True, timeout=60)
        regular(stripped)
        with stripped.open("rb") as stream:
            check_elf(stream, abi)
        record.update(apkBytes=stripped.stat().st_size, apkSha256=digest(stripped))
    elif file.name == ONNX_RUNTIME:
        if record["sha256"] != runtime_hashes()[abi]:
            raise ValueError(f"native ONNX runtime checksum mismatch for {abi}")
        record.update(apkBytes=record["bytes"], apkSha256=record["sha256"])
    else:
        raise ValueError("unexpected native producer library")
    return record


def artifact_name(context: dict, abi: str) -> str:
    if abi not in TARGETS:
        raise ValueError("unsupported Android ABI")
    return f"wallet-native-{context['runId']}-{context['runAttempt']}-{context['commit']}-{abi}"


def export_artifact(native_root: Path, output: Path, abi: str, context: dict, tool: Path) -> dict:
    if abi not in TARGETS:
        raise ValueError("unsupported Android ABI")
    directory(native_root)
    source = native_root / abi
    directory(source)
    if {p.name for p in native_root.iterdir()} != {abi}:
        raise ValueError("native producer must build exactly its assigned ABI")
    if {p.name for p in source.iterdir()} != {BRIDGE, ONNX_RUNTIME}:
        raise ValueError("native producer must contain exactly the bridge and ONNX runtime")
    if output.exists() or output.is_symlink():
        raise ValueError("native artifact output must be new")
    output.mkdir(parents=True)
    try:
        records = {}
        with tempfile.TemporaryDirectory(prefix="wallet-native-strip-") as temp:
            for name in (BRIDGE, ONNX_RUNTIME):
                records[name] = library_record(source / name, abi, tool, Path(temp))
                shutil.copyfile(source / name, output / name)
                if digest(output / name) != records[name]["sha256"]:
                    raise ValueError("native library changed while exporting")
        result = {"schema": SCHEMA, "context": context, "abi": abi,
                  "flutterTarget": TARGETS[abi][0], "rustTarget": TARGETS[abi][1],
                  "stripToolSha256": digest(tool), "libraries": records}
        (output / "manifest.json").write_text(json.dumps(result, sort_keys=True, indent=2) + "\n",
                                             encoding="utf-8")
        return result
    except BaseException:
        shutil.rmtree(output)
        raise


def validate_artifacts(root: Path, context: dict, tool: Path) -> dict[str, dict]:
    directory(root)
    expected = {artifact_name(context, abi) for abi in TARGETS}
    if {p.name for p in root.iterdir()} != expected:
        raise ValueError("expected exactly three native artifacts from the current run and attempt")
    validated = {}
    with tempfile.TemporaryDirectory(prefix="wallet-native-check-") as temp:
        for abi in TARGETS:
            artifact = root / artifact_name(context, abi)
            directory(artifact)
            if {p.name for p in artifact.iterdir()} != {"manifest.json", BRIDGE, ONNX_RUNTIME}:
                raise ValueError("unexpected or missing native artifact file")
            manifest = read_manifest(artifact / "manifest.json")
            if set(manifest) != {"schema", "context", "abi", "flutterTarget", "rustTarget",
                                 "stripToolSha256", "libraries"}:
                raise ValueError("unexpected native manifest shape")
            if (manifest["schema"] != SCHEMA or manifest["context"] != context
                    or manifest["abi"] != abi or manifest["flutterTarget"] != TARGETS[abi][0]
                    or manifest["rustTarget"] != TARGETS[abi][1]
                    or manifest["stripToolSha256"] != digest(tool)):
                raise ValueError("native artifact provenance does not match the current build")
            if not isinstance(manifest["libraries"], dict) or set(manifest["libraries"]) != {BRIDGE, ONNX_RUNTIME}:
                raise ValueError("native manifest must describe exactly two libraries")
            for name in (BRIDGE, ONNX_RUNTIME):
                record = manifest["libraries"][name]
                if not isinstance(record, dict) or set(record) != {"bytes", "sha256", "apkBytes", "apkSha256"}:
                    raise ValueError("unexpected native library record")
                if (any(type(record[key]) is not int or not 64 <= record[key] <= MAX_LIBRARY
                        for key in ("bytes", "apkBytes"))
                        or any(not isinstance(record[key], str) or not HASH.fullmatch(record[key])
                               for key in ("sha256", "apkSha256"))):
                    raise ValueError("invalid native library size or digest")
                if library_record(artifact / name, abi, tool, Path(temp)) != record:
                    raise ValueError("native library bytes or stripped APK digest changed")
            validated[abi] = manifest
    return validated


def stage_artifacts(root: Path, output: Path, context: dict, tool: Path) -> dict:
    manifests = validate_artifacts(root, context, tool)
    if output.exists() or output.is_symlink():
        raise ValueError("native staging requires a new output directory")
    output.mkdir(parents=True)
    try:
        for abi, manifest in manifests.items():
            destination = output / abi
            destination.mkdir()
            for name in (BRIDGE, ONNX_RUNTIME):
                shutil.copyfile(root / artifact_name(context, abi) / name, destination / name)
                if digest(destination / name) != manifest["libraries"][name]["sha256"]:
                    raise ValueError("native library changed while staging")
    except BaseException:
        shutil.rmtree(output)
        raise
    return manifests


def verify_apk_bytes(archive, manifests: dict[str, dict]) -> None:
    """Check the exact source-produced bytes, including AGP's pinned strip step."""
    if set(manifests) != set(ABIS):
        raise ValueError("APK provenance requires all three native producers")
    for abi, manifest in manifests.items():
        for name in (BRIDGE, ONNX_RUNTIME):
            expected = manifest["libraries"][name]
            info = archive.getinfo(f"lib/{abi}/{name}")
            with archive.open(info) as stream:
                if (info.file_size != expected["apkBytes"]
                        or hashlib.file_digest(stream, "sha256").hexdigest() != expected["apkSha256"]):
                    raise ValueError(f"APK {name} does not match its source-built artifact for {abi}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    producer = commands.add_parser("export")
    producer.add_argument("--abi", choices=TARGETS, required=True)
    producer.add_argument("--native-root", type=Path, required=True)
    producer.add_argument("--output", type=Path, required=True)
    consumer = commands.add_parser("stage")
    consumer.add_argument("--artifacts", type=Path, required=True)
    consumer.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    context, tool = current_context(), strip_tool()
    if args.command == "export":
        result = export_artifact(args.native_root, args.output, args.abi, context, tool)
        print(json.dumps({"artifact": artifact_name(context, args.abi), "manifest": result}, sort_keys=True))
    else:
        manifests = stage_artifacts(args.artifacts, args.output, context, tool)
        print(json.dumps({"source": context, "abis": list(manifests),
                          "scope": "same-run source-built native transfer; not device acceptance"}, sort_keys=True))


if __name__ == "__main__":
    main()
