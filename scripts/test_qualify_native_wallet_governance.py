"""Driver safety regressions; these mocks do not qualify native wallet behavior."""
import json
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import qualify_native_wallet_governance as subject


class CleanupTests(unittest.TestCase):
    def test_receiver_failure_still_attempts_guarded_container_removal(self):
        server = SimpleNamespace(active_connection=None, server_close=Mock(side_effect=RuntimeError("receiver")))
        with patch.object(subject, "remove_owned") as remove:
            with self.assertRaisesRegex(RuntimeError, "receiver:RuntimeError"):
                subject.cleanup_fixtures(server, None, "owned-name", "owned-id", "nonce")
        remove.assert_called_once_with("owned-name", "owned-id", "nonce")

    def test_both_cleanup_failures_are_reported(self):
        server = SimpleNamespace(active_connection=None, server_close=Mock(side_effect=OSError("receiver")))
        with patch.object(subject, "remove_owned", side_effect=RuntimeError("bao")) as remove:
            with self.assertRaisesRegex(RuntimeError, "receiver:OSError,bao:RuntimeError"):
                subject.cleanup_fixtures(server, None, "owned-name", "owned-id", "nonce")
        remove.assert_called_once()

    def test_foreign_nonce_never_reaches_destructive_docker_operation(self):
        cid, calls = "a" * 64, []
        metadata = {"Id": cid, "Name": "/owned-name", "Config": {"Labels": {
            "codex.purpose": subject.OWNER, "marty.disposable": "wallet-governed-native", "marty.fixture.nonce": "foreign"}}}

        def docker(*args, **_):
            calls.append(args)
            return json.dumps([metadata]) if args[0] == "inspect" else cid
        with patch.object(subject, "docker_ok", side_effect=docker):
            with self.assertRaisesRegex(RuntimeError, "marker identity changed"):
                subject.remove_owned("owned-name", cid, "expected")
        self.assertTrue(all(args[0] != "rm" for args in calls))

    def test_incomplete_allocation_recovery_uses_the_same_guard(self):
        metadata = [{"Id": "b" * 64}]
        with patch.object(subject, "docker", return_value=SimpleNamespace(returncode=0, stdout=json.dumps(metadata))), \
                patch.object(subject, "remove_owned") as remove:
            subject.cleanup_fixtures(None, None, "owned-name", None, "expected-nonce")
        remove.assert_called_once_with("owned-name", "b" * 64, "expected-nonce")


if __name__ == "__main__":
    unittest.main()
