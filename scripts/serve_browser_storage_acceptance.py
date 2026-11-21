"""Serve only the synthetic Flutter storage harness on a fresh loopback origin.

Use a new port/origin per JS or WASM run. Send `stop` on stdin, or POST to
`/__marty_owned_browser_stop` with the nonce in X-Marty-Test-Nonce, to retire it.
This never serves an existing installation or migrates its browser data.
"""
import argparse
from functools import partial
import http.server
import json
from pathlib import Path
import re
import secrets
import sys
import threading


def serve(root: Path, nonce: str):
    root = root.resolve(strict=True)
    if not re.fullmatch(r"[a-f0-9]{32}", nonce):
        raise RuntimeError("owned browser fixture nonce required")
    if any(path.is_symlink() for path in root.rglob("*")):
        raise RuntimeError("refuse linked browser fixture inputs")
    script = root / "main.dart.js"
    if not script.is_file() or b"__marty_owned_browser_guard" not in script.read_bytes():
        raise RuntimeError("refuse non-qualification browser build")
    counts = {"requests": 0, "dart_js": 0, "dart_wasm": 0, "dart_mjs": 0}

    class Handler(http.server.SimpleHTTPRequestHandler):
        extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                          ".wasm": "application/wasm", ".mjs": "text/javascript"}

        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def log_message(self, *_):
            pass

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            super().end_headers()

        def do_GET(self):
            counts["requests"] += 1
            path = self.path.split("?", 1)[0]
            if path == "/__marty_owned_browser_guard":
                body = nonce.encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            for name, field in [("main.dart.js", "dart_js"), ("main.dart.wasm", "dart_wasm"), ("main.dart.mjs", "dart_mjs")]:
                if path == "/" + name:
                    counts[field] += 1
            super().do_GET()

        def do_POST(self):
            if (self.path != "/__marty_owned_browser_stop"
                    or self.headers.get("X-Marty-Test-Nonce") != nonce
                    or self.headers.get("Content-Length", "0") != "0"):
                self.send_error(403)
                return
            self.send_response(204)
            self.end_headers()
            threading.Thread(target=server.shutdown, daemon=True).start()

    class Server(http.server.ThreadingHTTPServer):
        daemon_threads = True
        slots = threading.BoundedSemaphore(16)

        def process_request(self, request, client_address):
            if not self.slots.acquire(timeout=15):
                self.shutdown_request(request)
                return
            try:
                super().process_request(request, client_address)
            except BaseException:
                self.slots.release()
                raise

        def process_request_thread(self, request, client_address):
            try:
                super().process_request_thread(request, client_address)
            finally:
                self.slots.release()

    server = Server(("127.0.0.1", 0), partial(Handler, directory=str(root)))
    timer = threading.Timer(900, server.shutdown)
    timer.daemon = True

    def stop():
        for command in sys.stdin:
            if command.strip() == "stop":
                server.shutdown()
                return

    threading.Thread(target=stop, daemon=True).start()
    timer.start()
    print(json.dumps({"origin": f"http://127.0.0.1:{server.server_port}", "nonce": nonce}), flush=True)
    try:
        server.serve_forever()
    finally:
        timer.cancel()
        server.server_close()
        print(json.dumps({"retired": True, **counts}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--nonce", default=secrets.token_hex(16))
    args = parser.parse_args()
    serve(args.root, args.nonce)
