#!/usr/bin/env python3
"""Qualify the actual native wallet on newly owned TLS/non-exportable fixtures.

This is native application execution, not installed-wallet, deployed governance,
rootless-installation or external-suite acceptance. No existing Bao is admitted.
"""
from __future__ import annotations

import argparse
import http.server
import json
import os
from pathlib import Path
import platform
import re
import secrets
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

IMAGE = "quay.io/openbao/openbao@sha256:6150c4a6b62067db6141c8da7a6a6b5763f4f47c315343d0c848b40fecdfd452"
OWNER = "marty-wallet-native-qualification"
CASE = "operations::governed_presentation::native_tests::actual_remote_keys_authenticate_consent_and_submit_once_with_fresh_scope"
TLS_DENY_CASE = "operations::governed_presentation::native_tests::actual_receiver_with_untrusted_ca_cannot_receive_a_native_presentation"
ISSUANCE_CASE = "operations::verified_issuance::native_tests::actual_remote_receipt_authorizes_before_token_and_rechecks_after_response"


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def docker(*args, timeout=60):
    try:
        return subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        raise RuntimeError("owned Docker operation timed out") from None


def docker_ok(*args, timeout=60):
    result = docker(*args, timeout=timeout)
    # Docker command arguments can contain a disposable token; never print them.
    require(result.returncode == 0, "owned Docker operation failed")
    return result.stdout.strip()


def openssl_ok(*args):
    result = subprocess.run(["openssl", *args], capture_output=True, timeout=30, check=False)
    require(result.returncode == 0, "owned receiver TLS material unavailable")


def remove_owned(name, cid, nonce):
    require(re.fullmatch(r"[a-f0-9]{64}", cid), "invalid owned container identity")
    if not docker_ok("ps", "-aq", "--filter", f"id={cid}"):
        return
    metadata = json.loads(docker_ok("inspect", cid))[0]
    labels = metadata["Config"].get("Labels") or {}
    require(metadata["Id"] == cid and metadata["Name"] == f"/{name}"
            and labels.get("codex.purpose") == OWNER
            and labels.get("marty.disposable") == "wallet-governed-native",
            "refuse unowned fixture cleanup")
    require(labels.get("marty.fixture.nonce") == nonce, "owned marker identity changed")
    docker_ok("rm", "-f", "-v", cid)
    require(not docker_ok("ps", "-aq", "--filter", f"id={cid}"), "owned cleanup not verified")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        return None


def executable(artifacts):
    rows = [json.loads(line) for line in artifacts.read_text().splitlines() if line.strip()]
    require(any(row.get("reason") == "build-finished" and row.get("success") is True for row in rows),
            "successful compiler artifact record required")
    paths = {row["executable"] for row in rows if row.get("reason") == "compiler-artifact"
             and row.get("target", {}).get("name") == "marty_authenticator_bridge"
             and "cdylib" in row.get("target", {}).get("kind", [])
             and row.get("profile", {}).get("test") is True and row.get("executable")}
    require(len(paths) == 1, "one actual native test artifact required")
    binary = Path(paths.pop()).resolve(strict=True)
    require(binary.is_file() and os.access(binary, os.X_OK), "native executable required")
    listed = subprocess.run([str(binary), "operations::governed_presentation::native_tests::", "--ignored", "--list"],
                            capture_output=True, text=True, timeout=30, check=False)
    require(listed.returncode == 0 and {line.removesuffix(": test") for line in listed.stdout.splitlines()
            if line.endswith(": test")} == {CASE, TLS_DENY_CASE}, "both exact native cases must exist before allocation")
    listed = subprocess.run([str(binary), ISSUANCE_CASE, "--ignored", "--list"],
                            capture_output=True, text=True, timeout=30, check=False)
    require(listed.returncode == 0 and {line.removesuffix(": test") for line in listed.stdout.splitlines()
            if line.endswith(": test")} == {ISSUANCE_CASE}, "exact native issuance case must exist before allocation")
    return binary


def cleanup_fixtures(server, thread, name, cid, nonce):
    cleanup_errors = []
    try:
        if server is not None:
            connection = server.active_connection
            if connection is not None:
                try:
                    connection.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                connection.close()
            if thread is not None and thread.is_alive():
                stopper = threading.Thread(target=server.shutdown, daemon=True)
                stopper.start()
                stopper.join(timeout=15)
                require(not stopper.is_alive(), "owned receiver shutdown timed out")
            server.server_close()
        if thread is not None:
            thread.join(timeout=10)
            require(not thread.is_alive(), "owned receiver did not stop")
    except Exception as error:
        cleanup_errors.append("receiver:" + type(error).__name__)
    finally:
        # Even failed receiver teardown must attempt guarded Bao removal.
        try:
            if cid is not None:
                remove_owned(name, cid, nonce)
            else:
                recovery = docker("inspect", "--type", "container", name)
                if recovery.returncode == 0:
                    remove_owned(name, json.loads(recovery.stdout)[0]["Id"], nonce)
                else:
                    require("No such" in recovery.stderr, "owned allocation cleanup could not be verified")
        except Exception as error:
            cleanup_errors.append("bao:" + type(error).__name__)
    require(not cleanup_errors, "owned fixture cleanup incomplete: " + ",".join(cleanup_errors))


def qualify(binary):
    require(platform.system() == "Linux", "native fixture CA isolation requires Linux")
    if docker("image", "inspect", IMAGE).returncode != 0:
        docker_ok("pull", IMAGE, timeout=180)
    nonce, token = secrets.token_hex(32), secrets.token_urlsafe(32)
    name, cid = "wallet-native-" + nonce[:12], None
    server = thread = None
    with tempfile.TemporaryDirectory(prefix="marty-wallet-native-") as directory:
        private = Path(directory)
        os.chmod(private, 0o700)
        try:
            cid = docker_ok("run", "--pull=never", "--rm", "-d", "--name", name,
                "--label", f"codex.purpose={OWNER}", "--label", "marty.disposable=wallet-governed-native",
                "--label", f"marty.fixture.nonce={nonce}",
                "--memory", "256m", "--memory-swap", "256m", "--pids-limit", "64",
                "--tmpfs", "/tmp/bao-tls:rw,mode=1777", "-e", f"BAO_DEV_ROOT_TOKEN_ID={token}",
                "-p", "127.0.0.1::8200", IMAGE, "server", "-dev", "-dev-tls",
                "-dev-listen-address=0.0.0.0:8200", "-dev-tls-cert-dir=/tmp/bao-tls")
            require(re.fullmatch(r"[a-f0-9]{64}", cid), "invalid fixture container ID")
            binding = docker_ok("port", cid, "8200/tcp")
            require(re.fullmatch(r"127\.0\.0\.1:[0-9]+", binding), "owned loopback port required")
            base = f"https://{binding}"
            ca = private / "bao-ca.pem"
            for _ in range(40):
                result = docker("exec", cid, "cat", "/tmp/bao-tls/vault-ca.pem")
                if result.returncode == 0 and "BEGIN CERTIFICATE" in result.stdout:
                    ca.write_text(result.stdout, encoding="ascii")
                    break
                time.sleep(0.25)
            require(ca.is_file(), "owned public CA unavailable")
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=str(ca))))

            def call(method, path, body=None):
                request = urllib.request.Request(base + "/v1/" + path,
                    data=None if body is None else json.dumps(body).encode(), method=method,
                    headers={"X-Vault-Token": token, "Content-Type": "application/json"})
                try:
                    with opener.open(request, timeout=10) as response:
                        response.read(128 * 1024)
                        return response.status
                except urllib.error.HTTPError as error:
                    return error.code
            for _ in range(40):
                try:
                    if call("GET", "sys/health") == 200:
                        break
                except (OSError, urllib.error.URLError):
                    pass
                time.sleep(0.25)
            else:
                raise RuntimeError("owned TLS Bao unavailable")
            require(call("POST", "secret/data/marty-test-disposable-guard", {"data": {"nonce": nonce}}) in (200, 204), "owned marker failed")
            require(call("POST", "sys/mounts/transit", {"type": "transit"}) in (200, 204), "owned Transit failed")
            cert, key = private / "receiver-cert.pem", private / "receiver-key.pem"
            receiver_ca, ca_key = private / "receiver-ca.pem", private / "receiver-ca-key.pem"
            csr, extensions = private / "receiver.csr", private / "receiver.ext"
            # Ephemeral transport-only keys, never holder/issuer/request keys.
            openssl_ok("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                "-subj", "/CN=wallet-native-disposable-root", "-addext", "basicConstraints=critical,CA:TRUE",
                "-keyout", str(ca_key), "-out", str(receiver_ca))
            openssl_ok("req", "-newkey", "rsa:2048", "-nodes", "-subj", "/CN=wallet-native-disposable",
                "-keyout", str(key), "-out", str(csr))
            extensions.write_text("basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n")
            openssl_ok("x509", "-req", "-in", str(csr), "-CA", str(receiver_ca), "-CAkey", str(ca_key),
                "-CAcreateserial", "-days", "1", "-extfile", str(extensions), "-out", str(cert))
            os.chmod(key, 0o600)
            os.chmod(ca_key, 0o600)
            capture, hits = private / "receiver.json", []
            issuer_input = private / "issuer-input.json"
            issuer_capture = private / "issuer-capture.json"
            issuance_hits = {"token": 0, "nonce": 0, "credential": 0}

            class Receiver(http.server.BaseHTTPRequestHandler):
                def log_message(self, *_):
                    pass

                def reply(self, value):
                    body = json.dumps(value).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def do_GET(self):
                    if self.path != "/.well-known/openid-credential-issuer":
                        self.send_error(404)
                        return
                    service = f"https://127.0.0.1:{self.server.server_port}"
                    self.reply({"credential_issuer": service, "credential_endpoint": service + "/credential",
                        "token_endpoint": service + "/token", "nonce_endpoint": service + "/nonce",
                        "credential_configurations_supported": {"identity": {"format": "dc+sd-jwt",
                            "vct": "urn:elevenid:credential:identity", "cryptographic_binding_methods_supported": ["jwk"],
                            "proof_types_supported": {"jwt": {"proof_signing_alg_values_supported": ["ES256"]}}}}})

                def issuance(self):
                    size = int(self.headers.get("Content-Length", "0"))
                    require(0 <= size <= 65536, "invalid issuance request size")
                    body = self.rfile.read(size)
                    endpoint = self.path[1:]
                    if endpoint == "token":
                        form = urllib.parse.parse_qs(body.decode(), strict_parsing=True)
                        require(form == {"grant_type": ["urn:ietf:params:oauth:grant-type:pre-authorized_code"],
                            "pre-authorized_code": ["owned-fixture-code"]}, "invalid owned token request")
                        reply = {"access_token": "owned-fixture-token", "token_type": "Bearer", "expires_in": 120}
                    elif endpoint == "nonce":
                        reply = {"c_nonce": "owned-fixture-nonce", "c_nonce_expires_in": 120}
                    else:
                        require(self.headers.get("Authorization") == "Bearer owned-fixture-token", "invalid owned bearer")
                        request = json.loads(body)
                        require(set(request) == {"credential_configuration_id", "proofs"}
                            and request["credential_configuration_id"] == "identity"
                            and set(request["proofs"]) == {"jwt"}
                            and len(request["proofs"]["jwt"]) == 1, "invalid owned credential request")
                        issued = json.loads(issuer_input.read_text())
                        issued["transmitted_proof"] = request["proofs"]["jwt"][0]
                        issuer_input.write_text(json.dumps(issued))
                        reply = {"credentials": [{"credential": issued["credential"]}]}
                    issuance_hits[endpoint] += 1
                    issuer_capture.write_text(json.dumps(issuance_hits))
                    self.reply(reply)

                def do_POST(self):
                    try:
                        self.connection.settimeout(10)
                        if self.path in {"/token", "/nonce", "/credential"}:
                            self.issuance()
                            return
                        require(re.fullmatch(r"/v1/flows/instances/[0-9a-f-]{36}/submit", self.path), "unexpected recipient")
                        size = int(self.headers.get("Content-Length", "0"))
                        require(0 < size <= 1024 * 1024, "invalid submission size")
                        form = urllib.parse.parse_qs(self.rfile.read(size).decode("utf-8"), strict_parsing=True)
                        require(set(form) == {"state", "vp_token"} and all(len(v) == 1 for v in form.values()), "invalid submission shape")
                        require(self.path == f"/v1/flows/instances/{form['state'][0]}/submit", "state or recipient changed")
                        hits.append(True)
                        capture.write_text(json.dumps({"count": len(hits), "path": self.path,
                            "state": form["state"][0], "vp_token": form["vp_token"][0]}))
                        body = b'{"redirect_uri":"https://native-fixture-verifier.example/complete"}'
                        self.send_response(200)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(body)))
                        self.end_headers()
                        self.wfile.write(body)
                    except (RuntimeError, ValueError, UnicodeError, OSError, KeyError, TypeError):
                        self.send_error(400)

            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certfile=str(cert), keyfile=str(key))

            class OwnedServer(http.server.HTTPServer):
                active_connection = None

                def get_request(self):
                    connection, address = self.socket.accept()
                    connection.settimeout(10)
                    try:
                        secured = context.wrap_socket(connection, server_side=True)
                    except BaseException:
                        connection.close()
                        raise
                    self.active_connection = secured
                    return secured, address

                def shutdown_request(self, request):
                    super().shutdown_request(request)
                    self.active_connection = None

            server = OwnedServer(("127.0.0.1", 0), Receiver)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            trust = private / "fixture-trust.pem"
            trust.write_bytes(ca.read_bytes() + receiver_ca.read_bytes())
            empty_roots = private / "empty-cert-directory"
            empty_roots.mkdir()
            env = {key: value for key, value in os.environ.items()
                   if key.upper() not in {"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR"}}
            env.update(MARTY_TEST_OPENBAO_URL=base, MARTY_TEST_OPENBAO_TOKEN=token,
                MARTY_TEST_OPENBAO_DISPOSABLE_NONCE=nonce, MARTY_TEST_OPENBAO_CA_CERT=str(ca),
                MARTY_TEST_WALLET_OWNER_NONCE=nonce, MARTY_TEST_WALLET_RECEIVER=f"https://127.0.0.1:{server.server_port}/",
                MARTY_TEST_WALLET_CAPTURE=str(capture), SSL_CERT_FILE=str(trust), SSL_CERT_DIR=str(empty_roots), NO_PROXY="127.0.0.1,localhost")
            env.update(MARTY_TEST_WALLET_ISSUER_INPUT=str(issuer_input), MARTY_TEST_WALLET_ISSUER_CAPTURE=str(issuer_capture))
            for case, roots in [(TLS_DENY_CASE, ca), (ISSUANCE_CASE, trust), (CASE, trust)]:
                env["SSL_CERT_FILE"] = str(roots)
                result = subprocess.run([str(binary), case, "--ignored", "--exact", "--nocapture"],
                    env=env, capture_output=True, text=True, timeout=90, check=False)
                safe = (result.stdout + result.stderr).replace(token, "[disposable-token]").replace(nonce, "[disposable-marker]")
                safe = re.sub(r"\b(?:hvs|s)\.[A-Za-z0-9_.-]{12,}", "[disposable-token]", safe)
                safe = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[fixture-jws]", safe)
                print(safe, end="", flush=True)
                require(result.returncode == 0 and "1 passed; 0 failed; 0 ignored" in result.stdout,
                        "actual native wallet qualification failed")
                if case == TLS_DENY_CASE:
                    require(not hits, "untrusted receiver received a submission")
            require(len(hits) == 1, "native qualification did not submit exactly once")
            require(issuance_hits == {"token": 2, "nonce": 2, "credential": 2}, "native issuance did not exercise both responses")
        finally:
            cleanup_fixtures(server, thread, name, cid, nonce)
    print(json.dumps({"phase": "ok", "native_tests": 3, "submissions": 1, "credential_responses": 2,
        "scope": "actual native governed issuance and presentation with marked non-exportable TLS Transit keys, controlled HTTPS issuer and synthetic governance; not deployed governance, installed wallet, rootless qualification or official suite"}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", required=True, type=Path)
    args = parser.parse_args()
    qualify(executable(args.artifacts))
