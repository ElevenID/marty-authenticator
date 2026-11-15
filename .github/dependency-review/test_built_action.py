#!/usr/bin/env python3
"""Exercise the real built action with synthetic, loopback-only API responses.

No live GitHub token, dependency snapshot, repository context or policy is
changed. The child receives a newly constructed fixture environment. The
production action's source and executable bundle are never modified here.
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import math
import os
from pathlib import Path
import runpy
import shutil
import tempfile
import threading
from urllib.parse import parse_qs, urlencode, urlsplit


run_bounded = runpy.run_path(str(Path(__file__).resolve().parent.parent / "scripts/prepare_dependency_review.py"))["run_bounded"]


DENY = [
    "AGPL-1.0-only", "AGPL-1.0-or-later", "AGPL-3.0-only",
    "AGPL-3.0-or-later", "SSPL-1.0", "BUSL-1.1",
]
EXCLUSIONS = [
    "pkg:pub/flutter_rust_bridge@2.13.0", "pkg:pub/listen",
    "pkg:pub/permission_handler", "pkg:pub/permission_handler_android",
    "pkg:pub/permission_handler_apple", "pkg:pub/permission_handler_html",
    "pkg:pub/permission_handler_platform_interface",
    "pkg:pub/permission_handler_windows", "pkg:pub/win32",
]
LOWERCASE_ROWS = [
    ("app_links_linux", "1.0.5", "apache-2.0"),
    ("asn1lib", "1.6.8", "bsd-2-clause"),
    ("camera_android_camerax", "0.7.6+1", "bsd-3-clause"),
    ("camera_avfoundation", "0.11.1", "bsd-3-clause"),
    ("connectivity_plus", "7.3.2", "bsd-3-clause"),
    ("crypto", "3.0.8", "bsd-3-clause"),
    ("cupertino_ui", "1.0.2", "bsd-3-clause"),
    ("dbus", "0.8.0", "mpl-2.0"),
    ("flutter_riverpod", "3.5.0", "mit"),
    ("flutter_secure_storage", "10.3.4", "bsd-3-clause"),
    ("flutter_secure_storage_platform_interface", "2.1.1", "bsd-3-clause"),
    ("home_widget", "0.9.4", "bsd-3-clause"),
    ("local_auth_android", "2.3.0", "bsd-3-clause"),
    ("local_auth_darwin", "2.0.5", "bsd-3-clause"),
    ("logger", "2.8.0", "mit"),
    ("material_ui", "1.2.0", "bsd-3-clause"),
    ("nm", "0.6.0", "mpl-2.0"),
    ("objective_c", "9.5.0", "bsd-3-clause"),
    ("otp", "3.2.1", "mit"),
    ("riverpod", "3.5.0", "mit"),
    ("shared_preferences", "2.5.6", "bsd-3-clause"),
    ("source_gen", "4.2.4", "bsd-3-clause"),
    ("source_helper", "1.4.0", "apache-2.0"),
    ("cbor", ">= 6.5.1, < 7.0.0", "mit"),
]


def change(license: str | None, name: str = "fixture", version: str = "1.0.0") -> dict:
    return {
        "change_type": "added", "manifest": "pubspec.lock", "ecosystem": "pub",
        "name": name, "version": version, "package_url": f"pkg:pub/{name}@{version}",
        "license": license, "source_repository_url": None, "scope": "runtime",
        "vulnerabilities": [],
    }


def outputs(path: Path) -> dict[str, str]:
    lines = iter(path.read_text().splitlines())
    result = {}
    for line in lines:
        if "<<" not in line:
            key, value = line.split("=", 1)
        else:
            key, delimiter = line.split("<<", 1)
            parts = []
            for value in lines:
                if value == delimiter:
                    break
                parts.append(value)
            else:
                raise AssertionError("Truncated action output")
            value = "\n".join(parts)
        if key in result:
            raise AssertionError("Duplicate action output")
        result[key] = value
    return result


def execute(bundle: Path, changes: list[dict], directory: Path) -> dict:
    requests = []
    errors = []
    route = "/repos/fixture/subject/dependency-graph/compare/" + "a" * 40 + "..." + "b" * 40

    class FixtureAPI(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            parsed = urlsplit(self.path)
            query = parse_qs(parsed.query)
            if parsed.path != route or query.get("per_page") != ["5"]:
                errors.append("Unexpected API route")
                self.send_error(400)
                return
            if self.headers.get("Authorization") != "token fixture-not-a-real-token":
                errors.append("Unexpected fixture authorization")
                self.send_error(400)
                return
            page = int(query.get("page", ["1"])[0])
            requests.append(page)
            body = json.dumps(changes[(page - 1) * 5:page * 5]).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            if page * 5 < len(changes):
                next_query = urlencode({"per_page": "5", "page": str(page + 1)})
                self.send_header("Link", f'<http://127.0.0.1:{self.server.server_port}{route}?{next_query}>; rel="next"')
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            errors.append("Unexpected API mutation")
            self.send_error(400)

    server = HTTPServer(("127.0.0.1", 0), FixtureAPI)
    server.timeout = 2
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    event = directory / "event.json"
    event.write_text(json.dumps({"pull_request": {"number": 1, "base": {"sha": "a" * 40}, "head": {"sha": "b" * 40}}, "repository": {"private": False}}))
    output = directory / "outputs"
    summary = directory / "summary"
    output.touch()
    summary.touch()
    node = shutil.which("node")
    if node is None:
        raise AssertionError("Node is required for actual bundle execution")
    env = {
        "PATH": str(Path(node).resolve().parent) + ":/usr/bin:/bin",
        "LANG": "C.UTF-8", "TMPDIR": str(directory),
        "GITHUB_REPOSITORY": "fixture/subject",
        "GITHUB_EVENT_NAME": "pull_request", "GITHUB_EVENT_PATH": str(event),
        "GITHUB_API_URL": f"http://127.0.0.1:{server.server_port}",
        "GITHUB_SERVER_URL": "https://github.com", "GITHUB_WORKSPACE": str(directory),
        "GITHUB_OUTPUT": str(output), "GITHUB_STEP_SUMMARY": str(summary),
        "INPUT_REPO-TOKEN": "fixture-not-a-real-token",
        "INPUT_FAIL-ON-SEVERITY": "moderate", "INPUT_DENY-LICENSES": ",".join(DENY),
        "INPUT_ALLOW-DEPENDENCIES-LICENSES": ",".join(EXCLUSIONS),
        "INPUT_RETRY-ON-SNAPSHOT-WARNINGS": "true",
        "INPUT_RETRY-ON-SNAPSHOT-WARNINGS-TIMEOUT": "600",
        "INPUT_SHOW-OPENSSF-SCORECARD": "false",
        "NO_PROXY": "127.0.0.1", "no_proxy": "127.0.0.1",
    }
    if os.environ.get("RUNNER_TRACKING_ID"):
        env["RUNNER_TRACKING_ID"] = os.environ["RUNNER_TRACKING_ID"]
    log = directory / "action.log"
    try:
        # This official Node entrypoint launches no child tools for these API
        # fixtures. Keep it in the enclosing phase group, so an outer timeout
        # also settles the verifier; its own timeout terminates this exact child.
        code, captured = run_bounded([node, str(bundle)], directory, env, 15, new_group=False)
        log.write_bytes(captured)
        if errors:
            raise AssertionError(errors)
        expected_pages = list(range(1, max(1, math.ceil(len(changes) / 5)) + 1))
        if requests != expected_pages:
            raise AssertionError(f"Unexpected API requests {requests}: {log.read_text()[-1500:]}")
        result = outputs(output)
        raw = json.loads(result["dependency-changes"])
        if raw != changes:
            raise AssertionError("The built action changed raw dependency metadata")
        invalid = json.loads(result["invalid-license-changes"])
        for rows in invalid.values():
            if any(row not in changes for row in rows):
                raise AssertionError("The action changed an original report object")
        return {"exit": code, "unlicensed": len(invalid["unlicensed"]), "unresolved": len(invalid["unresolved"]), "forbidden": len(invalid["forbidden"]), "vulnerable": len(json.loads(result["vulnerable-changes"])), "requests": len(requests)}
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
        if thread.is_alive():
            raise AssertionError("The private fixture server did not settle")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--baseline", action="store_true", help="Assert the original upstream casing defect, only for local proof")
    args = parser.parse_args()
    bundle = args.bundle.resolve(strict=True)
    actual_rows = [change(license, name, version) for name, version, license in LOWERCASE_ROWS]
    actual_rows[-1]["manifest"] = "pubspec.yaml"
    moderate = change("MIT", "moderate-fixture")
    moderate["vulnerabilities"] = [{"severity": "moderate", "advisory_ghsa_id": "GHSA-fixture-only", "advisory_summary": "Synthetic moderate boundary", "advisory_url": "https://example.invalid/advisory"}]
    low = change("MIT", "low-fixture")
    low["vulnerabilities"] = [{**moderate["vulnerabilities"][0], "severity": "low"}]
    cases = [
        ("actual_24_lowercase_rows", actual_rows, (1, 0, 24, 0, 0) if args.baseline else (0, 0, 0, 0, 0)),
        ("all_denied_case_variants", [change(value.lower(), f"deny-{i}") for i, value in enumerate(DENY)], (1, 0, 6, 0, 0) if args.baseline else (1, 0, 0, 6, 0)),
        ("canonical_denied", [change(value, f"deny-{i}") for i, value in enumerate(DENY)], (1, 0, 0, 6, 0)),
        ("invalid_operator_and_unknown", [change(value, f"invalid-{i}") for i, value in enumerate(["mit or agpl-3.0-only", "MIT oR AGPL-3.0-only", "unknown-license", "none", "noassertion"])], (1, 0, 4, 0, 0)),
        ("existing_special_categories", [change(None, "null"), change("NOASSERTION", "noassertion"), change("LicenseRef-custom", "custom")], (0, 2, 0, 0, 0)),
        ("existing_exclusion", [change("AGPL-3.0-only", "permission_handler")], (0, 0, 0, 0, 0)),
        ("moderate_still_fails", [moderate], (1, 0, 0, 0, 1)),
        ("low_severity_unchanged", [low], (0, 0, 0, 0, 0)),
    ]
    reports = []
    with tempfile.TemporaryDirectory(prefix="dependency-review-bundle-test-", dir="/tmp") as temporary:
        for index, (name, changes, expected) in enumerate(cases):
            directory = Path(temporary) / str(index)
            directory.mkdir(mode=0o700)
            actual = execute(bundle, changes, directory)
            values = tuple(actual[key] for key in ("exit", "unlicensed", "unresolved", "forbidden", "vulnerable"))
            if values != expected:
                raise AssertionError(f"{name}: expected {expected}, received {values}")
            reports.append({"case": name, **actual})
    print(json.dumps({"mode": "original-baseline" if args.baseline else "repaired", "passed": len(reports), "failed": 0, "skipped": 0, "synthetic_loopback_API_only": True, "cases": reports}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
