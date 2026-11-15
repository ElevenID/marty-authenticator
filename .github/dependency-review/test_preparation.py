#!/usr/bin/env python3
"""Adversarial tests for the isolated, immutable action preparation boundary."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


HELPER = runpy.run_path(str(Path(__file__).resolve().parent.parent / "scripts/prepare_dependency_review.py"))
ERROR = HELPER["PreparationError"]
ACTION: Path


class PreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="dependency-review-guards-", dir="/tmp")
        cls.root = Path(cls.temporary.name)
        cls.clone = cls.root / "official-copy"
        HELPER["run_checked"](
            ["git", "clone", "--no-hardlinks", str(ACTION), str(cls.clone)],
            cls.root, HELPER["git_environment"](), 30,
        )
        cls.inventory = HELPER["verify_upstream"](cls.clone)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_exact_official_source_is_admitted(self):
        self.assertEqual(len(HELPER["verify_upstream"](self.clone)), 77)

    def test_tracked_byte_drift_is_rejected(self):
        path = self.clone / "src/licenses.ts"
        original = path.read_bytes()
        try:
            path.write_bytes(original + b"\n// unexpected drift\n")
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
        finally:
            path.write_bytes(original)

    def test_tracked_mode_drift_is_rejected(self):
        path = self.clone / "src/licenses.ts"
        try:
            path.chmod(0o755)
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
        finally:
            path.chmod(0o644)

    def test_nested_git_metadata_is_rejected(self):
        path = self.clone / "src/.git"
        path.mkdir()
        try:
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
        finally:
            path.rmdir()

    def test_untracked_npm_config_is_rejected(self):
        path = self.clone / ".npmrc"
        path.write_text("registry=https://example.invalid/fixture\n")
        try:
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
        finally:
            path.unlink()

    def test_metadata_symlink_and_worktree_file_are_rejected(self):
        metadata = self.clone / ".git"
        saved = self.root / "saved-metadata"
        metadata.rename(saved)
        try:
            metadata.symlink_to(saved, target_is_directory=True)
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
            metadata.unlink()
            metadata.write_text(f"gitdir: {saved}\n")
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
            metadata.unlink()
        finally:
            if metadata.is_symlink() or metadata.is_file():
                metadata.unlink()
            saved.rename(metadata)

    def test_extra_symlink_directory_is_rejected(self):
        path = self.clone / "src/unexpected"
        path.symlink_to(self.root, target_is_directory=True)
        try:
            with self.assertRaises(ERROR):
                HELPER["verify_upstream"](self.clone)
        finally:
            path.unlink()

    def test_regular_reader_rejects_symlink_hardlink_and_fifo(self):
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            regular = root / "input"
            regular.write_bytes(b"known")
            self.assertEqual(HELPER["regular_bytes"](regular), b"known")
            linked = root / "linked"
            linked.symlink_to(regular)
            with self.assertRaises(ERROR):
                HELPER["regular_bytes"](linked)
            linked.unlink()
            os.link(regular, linked)
            with self.assertRaises(ERROR):
                HELPER["regular_bytes"](regular)
            linked.unlink()
            fifo = root / "fifo"
            os.mkfifo(fifo)
            started = time.monotonic()
            with self.assertRaises(ERROR):
                HELPER["regular_bytes"](fifo)
            self.assertLess(time.monotonic() - started, 1)

    def test_missing_or_changed_pinned_identifier_table_fails(self):
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            for relative in HELPER["TABLES"]:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('["MIT"]\n')
            with self.assertRaises(ERROR):
                HELPER["canonical_data"](root)

    def test_generated_source_inventory_rejects_unrelated_drift(self):
        path = self.clone / "src/config.ts"
        original = path.read_bytes()
        try:
            path.write_bytes(original + b"\n// unrelated\n")
            with self.assertRaises(ERROR):
                HELPER["verify_inventory"](self.clone, self.inventory, {})
        finally:
            path.write_bytes(original)

    def test_environment_drops_candidate_hooks_and_credentials(self):
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            cache = root / "cache"
            cache.mkdir(mode=0o700)
            node = Path(shutil.which("node")).resolve()
            hostile = {"NODE_OPTIONS": "--require=/candidate/hook.cjs", "NODE_PATH": "/candidate/node_modules", "PYTHONPATH": "/candidate/python", "NPM_CONFIG_USERCONFIG": "/candidate/.npmrc", "NPM_CONFIG_GLOBALCONFIG": "/candidate/global", "NPM_CONFIG_SCRIPT_SHELL": "/candidate/shell", "NPM_TOKEN": "fixture-not-a-real-token", "GITHUB_TOKEN": "fixture-not-a-real-token", "NODE_TLS_REJECT_UNAUTHORIZED": "0"}
            with patch.dict(os.environ, hostile):
                env = HELPER["build_environment"](node, root, cache)
            self.assertEqual(env["NODE_OPTIONS"], "--max-old-space-size=1536")
            for key in hostile:
                if key not in {"NODE_OPTIONS", "NPM_CONFIG_USERCONFIG", "NPM_CONFIG_GLOBALCONFIG"}:
                    self.assertNotIn(key, env)
            self.assertEqual(Path(env["NPM_CONFIG_USERCONFIG"]).read_bytes(), b"")
            self.assertEqual(Path(env["NPM_CONFIG_GLOBALCONFIG"]).read_bytes(), b"")

    def test_proxy_credentials_and_checkout_supplied_ca_are_rejected(self):
        node = Path(shutil.which("node")).resolve()
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            cache = root / "cache"
            cache.mkdir()
            with self.assertRaises(ERROR):
                HELPER["build_environment"](node, root, cache, network_environment={"HTTPS_PROXY": "http://fixture:credential@localhost:1"})
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            cache = root / "cache"
            cache.mkdir()
            certificate = root / "candidate-ca.pem"
            certificate.write_text("fixture-public-certificate\n")
            with self.assertRaises(ERROR):
                HELPER["build_environment"](node, root, cache, network_environment={"NODE_EXTRA_CA_CERTS": str(certificate)}, blocked_roots=(root,))

    def test_real_npm_ignores_hostile_ancestor_workspace_and_hooks(self):
        with tempfile.TemporaryDirectory(dir=self.root) as temporary:
            root = Path(temporary)
            candidate = root / "candidate"
            validator = candidate / "validator"
            validator.mkdir(parents=True)
            marker = root / "unexpected-hook"
            hook = root / "hook.cjs"
            hook.write_text(f"require('node:fs').writeFileSync({json.dumps(str(marker))}, 'unexpected'); process.exit(59)\n")
            shell = root / "hostile-shell"
            shell.write_text(f"#!/bin/sh\nexec {shutil.which('node')} {hook}\n")
            shell.chmod(0o700)
            (candidate / "package.json").write_text(json.dumps({"name": "hostile-parent", "private": True, "workspaces": ["validator"], "scripts": {"test": "node fixture.cjs"}}))
            (candidate / ".npmrc").write_text(f"registry=https://example.invalid/hostile\nscript-shell={shell}\nnode-options=--require={hook}\n")
            package = {"name": "validator", "version": "1.0.0", "scripts": {key: "node safe.cjs" for key in ("test", "build", "package")}}
            (validator / "package.json").write_text(json.dumps(package))
            (validator / "package-lock.json").write_text(json.dumps({"name": "validator", "version": "1.0.0", "lockfileVersion": 3, "requires": True, "packages": {"": {"name": "validator", "version": "1.0.0"}}}))
            (validator / "safe.cjs").write_text("console.log('safe fixture')\n")
            node = Path(shutil.which("node")).resolve()
            npm = Path(shutil.which("npm")).resolve()
            cache = root / "cache"
            cache.mkdir(mode=0o700)
            env = HELPER["build_environment"](node, root, cache)
            # A benign negative control proves the ancestor really is active
            # without the production CLI prefix/workspace isolation.
            code, _ = HELPER["run_bounded"]([str(node), str(npm), "run", "test"], validator, env, 15)
            self.assertNotEqual(code, 0)
            self.assertTrue(marker.is_file())
            marker.unlink()
            commands = [
                ("--version",),
                ("config", "get", "registry"),
                ("ci", "--offline", "--ignore-scripts", "--no-audit", "--no-fund"),
                ("run", "test"), ("run", "build"), ("run", "package"),
            ]
            for arguments in commands:
                command = HELPER["npm_command"](node, npm, validator, *arguments)
                output = HELPER["run_checked"](command, validator, env, 15)
                self.assertFalse(marker.exists(), arguments)
                if arguments == ("config", "get", "registry"):
                    self.assertEqual(output.strip(), b"https://registry.npmjs.org/")

    def test_output_limit_settles_child(self):
        env = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"}
        with self.assertRaises(ERROR):
            HELPER["run_checked"]([sys.executable, "-I", "-c", "import os; os.write(1, b'x' * (9 * 1024 * 1024))"], self.root, env, 10)

    def test_timeout_settles_exact_owned_process(self):
        pidfile = self.root / "deadline-pid"
        code = f"import os,time; open({str(pidfile)!r}, 'w').write(str(os.getpid())); time.sleep(30)"
        with self.assertRaises(ERROR):
            HELPER["run_checked"]([sys.executable, "-I", "-c", code], self.root, {"PATH": "/usr/bin:/bin"}, 0.3)
        pid = int(pidfile.read_text())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", type=Path, required=True)
    args = parser.parse_args()
    ACTION = args.action.resolve(strict=True)
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PreparationTests))
    raise SystemExit(0 if result.wasSuccessful() else 1)
