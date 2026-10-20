"""Tests of tools/ci/size_guard.py and of the repository's size policy (REPO-01).

    python3 -m unittest discover -s tools/ci/tests -v

The scratch repositories write their blobs with `git hash-object --no-filters`, so the result does not depend on
whether git-lfs is installed on the machine. Works in the blobless sparse checkout of the CI job too.
"""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("size_guard", ROOT / "tools/ci/size_guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

ISOLATED = {"GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1", "GIT_AUTHOR_NAME": "Test",
            "GIT_AUTHOR_EMAIL": "test@example.com", "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com"}
ATTRIBUTES = """* text=auto eol=lf
*.png binary
[attr]plain-blob -filter -diff -merge -text
media/**/*.png filter=lfs diff=lfs merge=lfs -text
media/old.png plain-blob
"""
ALLOWLIST = """default 1KiB
lfs-object 4KiB
8KiB shipped/**
"""


def pointer(size):
    return ("version https://git-lfs.github.com/spec/v1\noid sha256:%s\nsize %d\n" % ("a" * 64, size)).encode()


class ScratchRepo:
    def __init__(self, path):
        self.path = Path(path)
        self.path.mkdir()
        self.git("init", "-q", "-b", "main")
        self.stage(".gitattributes", ATTRIBUTES.encode())

    def git(self, *args, data=None):
        return subprocess.run(["git", "-C", str(self.path), *args], input=data, capture_output=True, check=True).stdout

    def stage(self, path, data):
        oid = self.git("hash-object", "-w", "--no-filters", "--stdin", data=data).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", "100644,%s,%s" % (oid, path))

    def unstage(self, path):
        self.git("rm", "-q", "--cached", path)

    def commit(self, message):
        self.git("commit", "-q", "--no-verify", "-m", message)
        return self.git("rev-parse", "HEAD").decode().strip()


class GuardTests(unittest.TestCase):
    def setUp(self):
        patcher = mock.patch.dict(os.environ, ISOLATED)
        patcher.start()
        self.addCleanup(patcher.stop)
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.folder = Path(folder.name)
        self.allowlist = self.folder / "allowlist.txt"
        self.allowlist.write_text(ALLOWLIST)
        self.repo = ScratchRepo(self.folder / "repo")

    def run_guard(self, *args, repo=None):
        err = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            code = guard.main([*args, "--repo", str(repo or self.repo.path), "--allowlist", str(self.allowlist)])
        return code, err.getvalue()

    def test_small_and_allowlisted_blobs_pass(self):
        self.repo.stage("notes.txt", b"x" * 1024)
        self.repo.stage("shipped/art/sheet.webp", b"x" * 8192)
        self.assertEqual(self.run_guard("--staged"), (0, ""))

    def test_large_blob_outside_the_allowlist_is_rejected(self):
        self.repo.stage("docs/run.log", b"x" * 1025)
        self.repo.stage("shipped/art/sheet.webp", b"x" * 8193)
        code, err = self.run_guard("--staged")
        self.assertEqual(code, 1)
        self.assertIn("docs/run.log: 1 KiB is over the 1 KiB limit (default)", err)
        self.assertIn("shipped/art/sheet.webp: 8 KiB is over the 8 KiB limit (shipped/**)", err)

    def test_lfs_paths_need_pointers(self):
        self.repo.stage("media/qa/shot.png", b"\x89PNG tiny")
        code, err = self.run_guard("--staged")
        self.assertEqual(code, 1)
        self.assertIn("media/qa/shot.png: plain 9 B blob on a Git LFS path", err)
        self.repo.stage("media/qa/shot.png", pointer(4096))
        self.assertEqual(self.run_guard("--staged"), (0, ""))
        self.repo.stage("media/qa/shot.png", pointer(4097))
        code, err = self.run_guard("--staged")
        self.assertEqual(code, 1)
        self.assertIn("is over the 4 KiB lfs-object limit", err)

    def test_grandfathered_file_stays_plain_but_keeps_the_size_limit(self):
        self.repo.stage("media/old.png", b"x" * 1024)
        self.assertEqual(self.run_guard("--staged"), (0, ""))
        self.repo.stage("media/old.png", b"x" * 2048)
        code, err = self.run_guard("--staged")
        self.assertEqual(code, 1)
        self.assertIn("grandfathered: delete its line", err)

    def test_range_sees_a_blob_that_a_later_commit_removed(self):
        base = self.repo.commit("base")
        self.repo.stage("docs/big.bin", b"x" * 4096)
        self.repo.commit("add")
        self.repo.unstage("docs/big.bin")
        self.repo.commit("remove")
        code, err = self.run_guard("--range", base + "..HEAD")
        self.assertEqual(code, 1)
        self.assertIn("docs/big.bin: 4 KiB is over", err)
        self.assertEqual(self.run_guard("--range", "HEAD..HEAD")[0], 0)
        self.assertEqual(self.run_guard("--range", "HEAD")[0], 2)

    def test_audit_finds_plain_blobs_on_lfs_paths(self):
        self.repo.stage("media/old.png", b"x" * 4096)
        self.repo.stage("media/new.png", pointer(10))
        self.repo.commit("good")
        self.assertEqual(self.run_guard("--audit")[0], 0)
        self.repo.stage("media/sub/missed.png", b"plain")
        self.repo.commit("bad")
        code, err = self.run_guard("--audit")
        self.assertEqual(code, 1)
        self.assertIn("media/sub/missed.png: plain 5 B blob on a Git LFS path (narrow the LFS pattern", err)

    def test_blobless_clone_fetches_the_measured_blobs(self):
        base = self.repo.commit("base")
        self.repo.stage("docs/big.bin", b"y" * 4096)
        self.repo.stage("media/qa/shot.png", pointer(10))
        self.repo.commit("add")
        self.repo.git("config", "uploadpack.allowFilter", "true")
        self.repo.git("config", "uploadpack.allowAnySHA1InWant", "true")
        clone = self.folder / "clone"
        subprocess.run(["git", "clone", "-q", "--filter=blob:none", "--no-checkout", self.repo.path.as_uri(), str(clone)],
                       check=True, capture_output=True)
        code, err = self.run_guard("--range", base + "..HEAD", repo=clone)
        self.assertEqual(code, 1)
        self.assertEqual(err.count("over the"), 1, err)

    def test_bad_allowlist_is_a_usage_error(self):
        self.allowlist.write_text("default 1KiB\n")
        self.assertEqual(self.run_guard("--staged")[0], 2)
        self.allowlist.write_text("default 1KiB\nlfs-object 1 parsec\n")
        self.assertEqual(self.run_guard("--staged")[0], 2)

    def test_glob_stays_inside_a_component(self):
        self.assertTrue(guard.glob_regex("docs/qa/ui_baseline/*.png").match("docs/qa/ui_baseline/title.png"))
        self.assertFalse(guard.glob_regex("docs/qa/ui_baseline/*.png").match("docs/qa/ui_baseline/old/title.png"))
        self.assertTrue(guard.glob_regex("assets/**").match("assets/a/b/c.webp"))
        self.assertTrue(guard.glob_regex("a/**/x.png").match("a/x.png"))


class PolicyTests(unittest.TestCase):
    """The committed policy itself: LFS only where Godot never imports, shipped assets and UI baselines plain."""

    def attribute(self, path):
        out = subprocess.run(["git", "-C", str(ROOT), "check-attr", "filter", "--", path],
                             capture_output=True, text=True, check=True).stdout
        return out.rsplit(": ", 1)[-1].strip()

    def test_lfs_patterns_cover_only_gdignored_trees(self):
        trees = set()
        for line in (ROOT / ".gitattributes").read_text(encoding="utf-8").splitlines():
            if "filter=lfs" in line and not line.startswith("#"):
                trees.add(re.match(r"(.+?)/\*\*/", line).group(1))
        self.assertEqual(trees, {"docs", "tools/art"})
        for tree in trees:
            subprocess.run(["git", "-C", str(ROOT), "ls-files", "--error-unmatch", tree + "/.gdignore"],
                           check=True, capture_output=True)

    def test_where_new_files_go(self):
        self.assertEqual(self.attribute("docs/qa/some-new-run/shot.png"), "lfs")
        self.assertEqual(self.attribute("tools/art/drawn/sources/new_sheet.png"), "lfs")
        self.assertEqual(self.attribute("docs/audio/new_take.wav"), "lfs")
        self.assertNotEqual(self.attribute("assets/iso_props/new_prop.webp"), "lfs")
        self.assertNotEqual(self.attribute("docs/qa/ui_baseline/new_screen.png"), "lfs")
        self.assertNotEqual(self.attribute("docs/qa/some-new-run/report.json"), "lfs")

    def test_allowlist_parses_with_a_one_mib_default(self):
        limits, rules = guard.load_allowlist(guard.ALLOWLIST)
        self.assertEqual(limits["default"], 1024 ** 2)
        self.assertEqual(guard.limit_for("assets/iso_props/tree_giant_crown.webp", limits, rules)[1], "assets/**")
        self.assertEqual(guard.limit_for("docs/qa/mechanics/run.log", limits, rules)[1], "default")


if __name__ == "__main__":
    unittest.main()
