"""Exercise review invalidation without touching the real asset library."""
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import style_audit_current as audit


class ReviewedSnapshot(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.original = audit.ROOT, audit.OUT
        audit.ROOT = Path(self.scratch.name)
        audit.OUT = audit.ROOT / "review"
        audit.OUT.mkdir()
        self.asset = audit.ROOT / "assets/fixture.webp"
        self.asset.parent.mkdir()
        self.asset.write_bytes(b"reviewed export identity")
        self.review = {"status": "reviewed", "reviewed_assets": {"assets/fixture.webp": {
            "sha256": audit.sha(self.asset), "disposition": "accepted-painted"}}}
        self.save()

    def tearDown(self):
        audit.ROOT, audit.OUT = self.original
        self.scratch.cleanup()

    def save(self):
        (audit.OUT / "approval.json").write_text(json.dumps(self.review))

    def verify(self, passes):
        with contextlib.redirect_stdout(io.StringIO()):
            if passes:
                audit.check()
            else:
                with self.assertRaises(SystemExit):
                    audit.check()

    def test_unchanged_review_passes(self):
        self.verify(True)

    def test_replaced_art_invalidates_review(self):
        self.asset.write_bytes(b"different style export")
        self.verify(False)

    def test_new_art_needs_review(self):
        self.asset.with_name("new.webp").write_bytes(b"new art")
        self.verify(False)

    def test_removed_art_invalidates_review(self):
        self.asset.unlink()
        self.verify(False)

    def test_scan_is_not_visual_approval(self):
        self.review["status"] = "inspection_required"
        self.save()
        self.verify(False)

    def test_unknown_disposition_is_not_accepted(self):
        self.review["reviewed_assets"]["assets/fixture.webp"]["disposition"] = "unreviewed"
        self.save()
        self.verify(False)


if __name__ == "__main__":
    unittest.main()
