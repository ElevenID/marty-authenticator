#!/usr/bin/env python3
"""Build the reviewed SPDX identifier repair from immutable official inputs.

This prepares only an isolated checkout of the pinned action. It never edits
the runner's action cache, the candidate repository, dependency metadata, or
the action's policy inputs. Invoke with Python's isolated (-I) mode.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit


UPSTREAM_COMMIT = "a1d282b36b6f3519aa1f3fc636f609c47dddb294"
UPSTREAM_TREE = "fe066c3996066f90baea9d43bfb45dc9eaa47cea"
NODE_VERSION = "v24.22.1"
NPM_VERSION = "11.19.1"
PATCH_SHA256 = "e3f39fee69c417d70a79b9a8d0a2736032e56e3682d22275ad8016b353caee07"
TEST_SHA256 = "13e1661210ff0eec0e0b208df1b4c12ade051609e37a906308de63f4465a6103"
UNCHANGED = {
    "package.json": "99afcb2e83bea3ec8874f4082549b91839fea0d1971498fccc9265359af1ba35",
    "package-lock.json": "8d5034b0305a959a83ee92edd46e732e9e3056793e490ebc97087035bfb46819",
    "action.yml": "582ebeb27ae108f3d8786b5f7b29ddebc5bee3a5446e7ef2b94a3ac984cf587b",
}
PATCHED = {
    "src/spdx.ts": "e22ed4ff419c4b64ac8c6670f88995bc21274858e1c7f07096fdbcae6990fb6c",
    "src/licenses.ts": "7865fedfd76fbfe2204f18f2a02d2fe122b7d6d7205ac3f0cc29f5c3f3cae311",
}
TABLES = {
    "node_modules/spdx-license-ids/index.json": "d5ef45aff38fd904a68c563bf5814172bb0caa656220be820b3a81601e637241",
    "node_modules/spdx-license-ids/deprecated.json": "29c9e630daa0adc09dec96ddeb6f81d1046210e81824bebda6486250450fb130",
    "node_modules/spdx-exceptions/index.json": "fb214b95bdfce683a9ef080c3ba7a10bf45f7fde3dce422dbb3236c12783151a",
}
# Produced by the actual Node 24.22.1/npm 11.19.1 locked build. Both unchanged
# auxiliary artifacts also match the official distribution byte for byte.
EXPECTED_DIST = {
    "index.js": "f6bd456c2fce99cf0caea3cb8f5c951a340a71ccb2d09b5691c647a5f0cf82eb",
    "index.js.map": "4dcad1f77e31ed45a77e3124f953f419f2a1a0a2f3c1f7e7fcce41db068caae9",
    "licenses.txt": "7d4c404c7f2ffe5102670859d96f01769e0af6faaea0753784389fbbc3d80c47",
    "sourcemap-register.js": "c2a14a81784d12c15b7baeed88c1faae3457e84890d1e5244cbfc0f4455b5e06",
}
GENERATED = {
    "src/spdx-license-case-data.ts": "ae0adfe852580b186912b6b2330f1c036f99043b8659c52b4679c09704e33612",
}
OUTPUT_LIMIT = 8 * 1024 * 1024


class PreparationError(RuntimeError):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def regular_bytes(path: Path, limit: int = 16 * 1024 * 1024) -> bytes:
    if path.absolute() != path.resolve(strict=True):
        raise PreparationError(f"Noncanonical path: {path}")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        before = os.fstat(fd)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_uid != os.getuid()
            or before.st_nlink != 1
            or before.st_mode & 0o022
            or before.st_size > limit
        ):
            raise PreparationError(f"Unsafe or oversized input: {path}")
        data = bytearray()
        while len(data) <= limit:
            block = os.read(fd, min(65536, limit + 1 - len(data)))
            if not block:
                break
            data.extend(block)
        after = os.fstat(fd)
        identity = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns)
        if len(data) > limit or identity(before) != identity(after):
            raise PreparationError(f"Input changed while reading: {path}")
        return bytes(data)
    finally:
        os.close(fd)


def owned_directory(path: Path) -> Path:
    absolute = path.absolute()
    if absolute != absolute.resolve(strict=True):
        raise PreparationError(f"Noncanonical directory: {path}")
    info = absolute.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise PreparationError(f"Directory is not owned: {path}")
    if info.st_mode & 0o022:
        raise PreparationError(f"Directory is writable by others: {path}")
    return absolute


def run_bounded(
    command: list[str], cwd: Path, env: dict[str, str], timeout: int = 180,
    *, input_bytes: bytes | None = None, new_group: bool = True,
) -> tuple[int, bytes]:
    """Bound output and settle this command's own process group on failure."""
    process = subprocess.Popen(
        command,
        cwd=cwd,
        env=env,
        stdin=subprocess.PIPE if input_bytes is not None else subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=new_group,
    )
    assert process.stdout is not None
    output = bytearray()
    deadline = time.monotonic() + timeout
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        if input_bytes is not None:
            if len(input_bytes) > 4096:
                raise PreparationError("Command input exceeded its fixed patch bound")
            assert process.stdin is not None
            process.stdin.write(input_bytes)
            process.stdin.close()
        while selector.get_map():
            if time.monotonic() >= deadline:
                raise PreparationError(f"Command exceeded {timeout}s: {command[0]}")
            for key, _ in selector.select(min(0.2, deadline - time.monotonic())):
                block = os.read(key.fileobj.fileno(), 65536)
                if not block:
                    selector.unregister(key.fileobj)
                else:
                    output.extend(block)
                    if len(output) > OUTPUT_LIMIT:
                        raise PreparationError("Command output exceeded 8 MiB")
        code = process.wait(timeout=max(0.1, deadline - time.monotonic()))
        return code, bytes(output)
    finally:
        selector.close()
        process.stdout.close()
        # Settle even a descendant which closed its output before the parent.
        try:
            if new_group:
                os.killpg(process.pid, signal.SIGTERM)
            else:
                process.terminate()
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        try:
            if new_group:
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
        except ProcessLookupError:
            pass
        process.wait(timeout=2)


def run_checked(
    command: list[str], cwd: Path, env: dict[str, str], timeout: int = 180,
    *, input_bytes: bytes | None = None,
) -> bytes:
    code, output = run_bounded(command, cwd, env, timeout, input_bytes=input_bytes)
    if code:
        tail = output[-5000:].decode("utf-8", errors="replace")
        raise PreparationError(f"Command failed ({code}): {command[0]}\n{tail}")
    return output


def git_environment() -> dict[str, str]:
    return {
        "PATH": "/usr/bin:/bin",
        "LANG": "C.UTF-8",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_TERMINAL_PROMPT": "0",
    }


def verify_upstream(source: Path) -> dict[str, tuple[str, str]]:
    env = git_environment()
    metadata = source / ".git"
    if metadata.is_symlink() or not metadata.is_dir():
        raise PreparationError("A fresh ordinary action checkout is required")
    owned_directory(metadata)
    roots = run_checked(
        ["git", "rev-parse", "--show-toplevel", "--absolute-git-dir"], source, env, 15
    ).decode().splitlines()
    if roots != [str(source), str(metadata)]:
        raise PreparationError("Git metadata does not belong to this action checkout")
    head = run_checked(["git", "rev-parse", "HEAD"], source, env, 15).decode().strip()
    tree = run_checked(
        ["git", "rev-parse", "HEAD^{tree}"], source, env, 15
    ).decode().strip()
    if head != UPSTREAM_COMMIT or tree != UPSTREAM_TREE:
        raise PreparationError("The action checkout is not the pinned official source")
    raw = run_checked(
        ["git", "ls-tree", "-rz", "--full-tree", UPSTREAM_COMMIT], source, env, 15
    )
    inventory = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        header, name = entry.split(b"\t", 1)
        mode, kind, blob = header.decode().split(" ")
        name = name.decode()
        if kind != "blob" or mode not in {"100644", "100755"}:
            raise PreparationError("Unexpected upstream file mode")
        data = regular_bytes(source / name)
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        executable = bool((source / name).stat().st_mode & stat.S_IXUSR)
        if actual != blob or executable != (mode == "100755"):
            raise PreparationError(f"Upstream bytes or mode drifted: {name}")
        inventory[name] = (mode, blob)
    if len(inventory) != 77:
        raise PreparationError("Unexpected upstream inventory size")
    parents = {str(p.parent) for name in inventory for p in (Path(name), *Path(name).parents) if str(p.parent) != "."}
    for directory, names, filenames in os.walk(source):
        if Path(directory) == source:
            names[:] = [n for n in names if n != ".git"]
        for name in names:
            child = Path(directory) / name
            if child.is_symlink() or child.relative_to(source).as_posix() not in parents:
                raise PreparationError(f"Unexpected directory in fresh checkout: {child.name}")
        for name in filenames:
            rel = (Path(directory) / name).relative_to(source).as_posix()
            if rel not in inventory:
                raise PreparationError(f"The upstream checkout is not fresh: {rel}")
    return inventory


def verify_inventory(
    source: Path, inventory: dict[str, tuple[str, str]], overrides: dict[str, str]
) -> None:
    for name, (mode, expected_blob) in inventory.items():
        data = regular_bytes(source / name)
        actual_blob = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        correct = digest(data) == overrides[name] if name in overrides else actual_blob == expected_blob
        if not correct or bool((source / name).stat().st_mode & stat.S_IXUSR) != (mode == "100755"):
            raise PreparationError(f"Unexpected source drift: {name}")


def check_hashes(source: Path, expected: dict[str, str]) -> None:
    for name, expected_hash in expected.items():
        if digest(regular_bytes(source / name)) != expected_hash:
            raise PreparationError(f"Unexpected file content: {name}")


def canonical_data(source: Path) -> bytes:
    check_hashes(source, TABLES)
    values: dict[str, str] = {}
    reserved = {"and", "or", "with", "none", "noassertion", "other"}
    for name in TABLES:
        rows = json.loads(regular_bytes(source / name))
        if not isinstance(rows, list) or not rows:
            raise PreparationError("Malformed pinned SPDX table")
        for identifier in rows:
            if not isinstance(identifier, str) or not re.fullmatch(
                r"[A-Za-z0-9][A-Za-z0-9.-]*", identifier
            ):
                raise PreparationError("Malformed SPDX identifier")
            key = identifier.lower()
            if key in reserved or key.startswith(("licenseref-", "documentref-")):
                raise PreparationError("Reserved or custom identifier in SPDX table")
            if key in values and values[key] != identifier:
                raise PreparationError("Ambiguous SPDX identifier casing")
            values[key] = identifier
    if len(values) != 759:
        raise PreparationError("Unexpected pinned SPDX identifier count")
    lines = [
        "// Generated only from the unchanged official action lockfile's",
        "// spdx-license-ids 3.0.23 and spdx-exceptions 2.3.0 tables.",
        "// SPDX operators, special values, and custom references are excluded.",
        "export const canonicalIdentifiers = new Map<string, string>([",
    ]
    for key in sorted(values):
        line = f"  ['{key}', '{values[key]}'],"
        if len(line) <= 80:
            lines.append(line)
        else:
            lines.extend(["  [", f"    '{key}',", f"    '{values[key]}'", "  ],"])
    lines[-1] = lines[-1].removesuffix(",")
    lines.append("])\n")
    return "\n".join(lines).encode()


def stage_patch(source: Path, support: Path) -> dict[str, str]:
    patch = regular_bytes(support / "identifier-case.patch", 8192)
    test = regular_bytes(support / "identifier-case.test.ts", 32768)
    if digest(patch) != PATCH_SHA256 or digest(test) != TEST_SHA256:
        raise PreparationError("Reviewed patch or regression fixture changed")
    # Both invocations consume the same hash-verified bytes, never a second read.
    run_checked(["git", "apply", "--check", "--unidiff-zero"], source, git_environment(), 15, input_bytes=patch)
    baseline = source / "src/licenses.identifier-case-baseline.ts"
    fixture = source / "__tests__/identifier-case.test.ts"
    generated = source / "src/spdx-license-case-data.ts"
    for path in (baseline, fixture, generated):
        if path.exists() or path.is_symlink():
            raise PreparationError(f"Reserved preparation file already exists: {path.name}")
    original = regular_bytes(source / "src/licenses.ts")
    baseline.write_bytes(original)
    fixture.write_bytes(test)
    generated.write_bytes(canonical_data(source))
    run_checked(["git", "apply", "--unidiff-zero"], source, git_environment(), 15, input_bytes=patch)
    check_hashes(source, PATCHED)
    return {str(path.relative_to(source)): digest(regular_bytes(path)) for path in (baseline, fixture, generated)}


def build_environment(
    node: Path, temporary: Path, cache: Path, *,
    network_environment: dict[str, str] | None = None,
    blocked_roots: tuple[Path, ...] = (),
) -> dict[str, str]:
    config = temporary / "npm-config"
    config.mkdir(mode=0o700)
    for name in ("user", "global"):
        (config / name).write_bytes(b"")
    env = {
        "PATH": str(node.parent) + ":/usr/bin:/bin",
        "LANG": "C.UTF-8",
        "TZ": "UTC",
        "TMPDIR": str(temporary),
        "CI": "true",
        "NPM_CONFIG_USERCONFIG": str(config / "user"),
        "NPM_CONFIG_GLOBALCONFIG": str(config / "global"),
        "NPM_CONFIG_CACHE": str(cache),
        "NPM_CONFIG_IGNORE_SCRIPTS": "true",
        "NPM_CONFIG_AUDIT": "false",
        "NPM_CONFIG_FUND": "false",
        "NODE_OPTIONS": "--max-old-space-size=1536",
    }
    # Retain the runner's cancellation marker, never candidate or npm settings.
    if os.environ.get("RUNNER_TRACKING_ID"):
        env["RUNNER_TRACKING_ID"] = os.environ["RUNNER_TRACKING_ID"]
    # Some existing execution environments require their provisioned HTTPS
    # proxy and public CA. Preserve only that explicitly selected transport;
    # never inherit candidate npm config, Node hooks, credentials or TLS-disable
    # settings. The hosted workflow normally uses the system defaults.
    if network_environment is not None:
        for name in ("HTTP_PROXY", "HTTPS_PROXY"):
            value = network_environment.get(name) or network_environment.get(name.lower())
            if not value:
                continue
            parsed = urlsplit(value)
            if (
                len(value) > 2048 or any(c in value for c in "\r\n")
                or parsed.scheme not in {"http", "https"} or not parsed.hostname
                or parsed.username is not None or parsed.password is not None
                or parsed.path not in {"", "/"} or parsed.query or parsed.fragment
            ):
                raise PreparationError("Unsupported existing proxy transport")
            env[name] = value
            env[name.lower()] = value
            env["NPM_CONFIG_" + ("HTTPS_PROXY" if name == "HTTPS_PROXY" else "PROXY")] = value
        no_proxy = network_environment.get("NO_PROXY") or network_environment.get("no_proxy")
        if no_proxy:
            if len(no_proxy) > 8192 or any(c in no_proxy for c in "\r\n"):
                raise PreparationError("Malformed existing proxy exclusion setting")
            env["NO_PROXY"] = env["no_proxy"] = no_proxy
        certificate = network_environment.get("NODE_EXTRA_CA_CERTS")
        if certificate:
            path = Path(certificate)
            if not path.is_absolute() or path != path.resolve(strict=True):
                raise PreparationError("The existing host CA path must be canonical")
            info = path.stat()
            if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o022 or info.st_size > 1024 * 1024:
                raise PreparationError("Unsafe existing host CA input")
            if any(path == root or root in path.parents for root in blocked_roots):
                raise PreparationError("A checkout cannot supply network trust")
            env["NODE_EXTRA_CA_CERTS"] = str(path)
        if "HTTP_PROXY" in env or "HTTPS_PROXY" in env:
            env["NODE_OPTIONS"] += " --use-env-proxy"
    return env


def npm_command(node: Path, npm: Path, source: Path, *arguments: str) -> list[str]:
    # CLI prefix prevents npm from inspecting ancestor package/workspace config.
    # Environment-only prefix settings do not provide the same isolation.
    return [str(node), str(npm), "--prefix", str(source), "--workspaces=false", *arguments]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", type=Path, required=True)
    parser.add_argument("--offline-cache", type=Path)
    args = parser.parse_args()
    if not sys.flags.isolated:
        raise PreparationError("Run this helper with python3 -I")
    if set(EXPECTED_DIST) != {"index.js", "index.js.map", "licenses.txt", "sourcemap-register.js"}:
        raise PreparationError("The repaired distribution has not been admitted")
    source = owned_directory(args.action)
    support = Path(__file__).resolve().parent.parent / "dependency-review"
    if source == support or source in support.parents or support in source.parents:
        raise PreparationError("Trusted preparation and action checkouts must be disjoint")
    inventory = verify_upstream(source)
    check_hashes(source, UNCHANGED)
    node_name = shutil.which("node")
    npm_name = shutil.which("npm")
    if not node_name or not npm_name:
        raise PreparationError("The pinned Node and npm runtime is required")
    node = Path(node_name).resolve(strict=True)
    npm = Path(npm_name).resolve(strict=True)
    if node.parent.parent not in npm.parents:
        raise PreparationError("npm must belong to the selected Node installation")
    with tempfile.TemporaryDirectory(prefix="dependency-review-build-", dir="/tmp") as name:
        temporary = owned_directory(Path(name))
        cache = owned_directory(args.offline_cache) if args.offline_cache else temporary / "cache"
        if not args.offline_cache:
            cache.mkdir(mode=0o700)
        blocked = (source, support)
        if os.environ.get("GITHUB_WORKSPACE"):
            blocked += (Path(os.environ["GITHUB_WORKSPACE"]).resolve(strict=True),)
        env = build_environment(node, temporary, cache, network_environment=dict(os.environ), blocked_roots=blocked)
        if run_checked([str(node), "--version"], source, env, 10).decode().strip() != NODE_VERSION:
            raise PreparationError("Node version differs from the reviewed build")
        if run_checked(npm_command(node, npm, source, "--version"), source, env, 10).decode().strip() != NPM_VERSION:
            raise PreparationError("npm version differs from the reviewed build")
        preparation_tests = run_checked(
            [sys.executable, "-I", str(support / "test_preparation.py"), "--action", str(source)],
            source, env, 90,
        )
        print(preparation_tests.decode("utf-8", errors="replace"))
        install = npm_command(node, npm, source, "ci", "--ignore-scripts", "--no-audit", "--no-fund")
        if args.offline_cache:
            install.append("--offline")
        run_checked(install, source, env, 300)
        added = stage_patch(source, support)
        verify_inventory(source, inventory, PATCHED)
        check_hashes(source, GENERATED)
        tests = run_checked(npm_command(node, npm, source, "test", "--", "--runInBand", "--testTimeout=20000"), source, env, 180)
        print(tests.decode("utf-8", errors="replace"))
        check_hashes(source, added)
        (source / "src/licenses.identifier-case-baseline.ts").unlink()
        (source / "__tests__/identifier-case.test.ts").unlink()
        run_checked(npm_command(node, npm, source, "run", "format-check"), source, env, 60)
        run_checked(npm_command(node, npm, source, "run", "lint"), source, env, 120)
        run_checked(npm_command(node, npm, source, "run", "build"), source, env, 120)
        run_checked(npm_command(node, npm, source, "run", "package"), source, env, 120)
        check_hashes(source, UNCHANGED | PATCHED | GENERATED)
        check_hashes(source / "dist", EXPECTED_DIST)
        verify_inventory(source, inventory, PATCHED | {"dist/" + k: v for k, v in EXPECTED_DIST.items()})
        # This separate harness executes the unchanged action entrypoint itself
        # against a bounded loopback fixture, with no real API credentials.
        bundle_tests = run_checked([sys.executable, "-I", str(support / "test_built_action.py"), "--bundle", str(source / "dist/index.js")], source, env, 90)
        print(bundle_tests.decode("utf-8", errors="replace"))
        print(json.dumps({"upstream_commit": UPSTREAM_COMMIT, "upstream_tree": UPSTREAM_TREE, "node": NODE_VERSION, "npm": NPM_VERSION, "distribution": EXPECTED_DIST, "policy_inputs": "unchanged", "dependency_metadata": "unchanged"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (PreparationError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Dependency-review preparation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
