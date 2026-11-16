import hashlib
from pathlib import Path
import unittest

import audit_native_ownership as audit


class NativeOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.source = (Path(__file__).resolve().parents[1] / audit.STORAGE_PATH).read_text(encoding='utf-8')

    def test_reviewed_bounded_storage_decoder_and_windows_endings(self):
        self.assertEqual(audit.violations(audit.STORAGE_PATH, self.source), [])
        self.assertEqual(audit.violations(audit.STORAGE_PATH, self.source.replace('\n', '\r\n')), [])

    def test_exact_source_cannot_move_to_status_owner(self):
        self.assertTrue(audit.violations('lib/services/status_list_service.dart', self.source))

    def test_additional_decoder_or_changed_bounds_require_review(self):
        for changed in (self.source + '\nbase64Decode(statusList);', self.source.replace('2 * 1024 * 1024', '8 * 1024 * 1024')):
            with self.subTest(change=changed[-40:]):
                self.assertTrue(audit.violations(audit.STORAGE_PATH, changed))

    def test_signing_and_status_decoding_never_admitted_by_digest(self):
        for token in ('gzip.decode', 'Hmac(sha256', 'local-dev-secret'):
            changed = self.source + '\n' + token
            old = audit.STORAGE_SHA256
            try:
                audit.STORAGE_SHA256 = hashlib.sha256(changed.encode()).hexdigest()
                self.assertTrue(audit.violations(audit.STORAGE_PATH, changed))
            finally:
                audit.STORAGE_SHA256 = old

    def test_unrelated_sources_and_arbitrary_decoders(self):
        self.assertEqual(audit.violations('lib/models/receipt.dart', 'class Receipt {}'), [])
        self.assertTrue(audit.violations('lib/views/liveness.dart', 'base64Decode(payload);'))


if __name__ == '__main__':
    unittest.main()
