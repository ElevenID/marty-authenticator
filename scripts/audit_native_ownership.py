"""Keep status decoding and liveness signing owned by Rust.

The reviewed legacy browser-storage decoder uses Base64 only for bounded,
canonical local persistence migration. Admit its exact source, not a directory
or arbitrary Base64 use. Line endings are normalized for Windows checkouts.
"""
import hashlib
from pathlib import Path
import re
import sys

STORAGE_PATH = 'lib/services/browser_storage_migration.dart'
STORAGE_SHA256 = '287af74b15af43f3d79fb87dd3d61e81d052973ee2089d6be08e7e0e64579fc9'
ALWAYS_FORBIDDEN = re.compile(r'gzip\.decode|Hmac\(sha256|local-dev-secret')
BASE64 = re.compile(r'base64Decode\(')


def violations(relative, source):
    source = source.replace('\r\n', '\n')
    found = []
    if ALWAYS_FORBIDDEN.search(source):
        found.append('status decoding or liveness signing must remain in Rust')
    if BASE64.search(source) and not (
        relative == STORAGE_PATH
        and hashlib.sha256(source.encode('utf-8')).hexdigest() == STORAGE_SHA256
        and len(BASE64.findall(source)) == 1
    ):
        found.append('unreviewed Base64 decoder outside exact legacy storage owner')
    return found


def main():
    root = Path(__file__).resolve().parents[1]
    failures = []
    for area in ('lib/models', 'lib/services', 'lib/views'):
        for path in sorted((root / area).rglob('*.dart')):
            relative = path.relative_to(root).as_posix()
            failures.extend((relative, message) for message in violations(
                relative, path.read_text(encoding='utf-8')))
    for relative, message in failures:
        print(f'{relative}: {message}', file=sys.stderr)
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
