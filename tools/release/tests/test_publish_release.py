"""Offline GitHub REST/gh subprocess fixtures; no credentials or external writes."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from typing import Any, Callable
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/release"))
import release

TAG = "v1.2.3"
REPO = "example/Traetoppen"
BASE = f"repos/{REPO}"


def response(data, status=200):
    return subprocess.CompletedProcess([], 0 if status < 400 else 1,
        f"HTTP/2.0 {status} Response\r\nContent-Type: application/json; charset=utf-8\r\n\r\n" + json.dumps(data),
        "" if status < 400 else f"gh: API failure (HTTP {status})")


class GitHubFixture:
    """Stateful REST-shaped service behind the production subprocess boundary."""
    def __init__(self, dist):
        self.dist = dist
        self.release: Any = None
        self.assets = []
        self.latest = None
        self.events = []
        self.hook: Callable | None = None

    def run(self, command, **options):
        assert options["capture_output"] and options["text"]
        assert 0 < options["timeout"] <= 300
        assert command[0] == "gh"
        if command[1] == "api":
            method = command[command.index("--method") + 1]
            path = command[-1]
            payload = json.loads(options["input"]) if options.get("input") else None
            event = (method, path, payload)
        else:
            event = (command[2], command, None)
        self.events.append(copy.deepcopy(event))
        if self.hook:
            override = self.hook(event)
            if override is not None:
                return override
        verb, path, payload = event
        if verb == "GET":
            if path == BASE:
                return response({"id": 123, "full_name": REPO})
            if path == f"{BASE}/git/ref/tags/{TAG}":
                return response({"ref": f"refs/tags/{TAG}", "object": {"type": "commit", "sha": "a" * 40}})
            if path == f"{BASE}/releases/latest":
                return response(self.release if self.latest == 42 else {"message": "Not Found"}, 200 if self.latest == 42 else 404)
            if path == f"{BASE}/releases/42/assets?per_page=100":
                return response(self.assets)
            if path.startswith(f"{BASE}/releases?per_page=100&page="):
                return response([self.release] if self.release else [])
            if path == f"{BASE}/releases/tags/{TAG}":
                published = self.release is not None and not self.release["draft"]
                return response(self.release if published else {"message": "Not Found"}, 200 if published else 404)
            if path == f"{BASE}/releases/42":
                return response(self.release or {"message": "Not Found"}, 200 if self.release else 404)
        if verb == "PATCH" and path == f"{BASE}/releases/42":
            assert isinstance(payload, dict)
            if payload.get("make_latest") == "true":
                assert len(self.assets) == 9, "partial releases must never be promoted"
                self.latest = 42
            if payload.get("draft"):
                self.latest = None
            self.release.update({key: value for key, value in payload.items() if key != "make_latest"})
            return response(self.release)
        if verb == "create":
            assert self.release is None
            assert "--draft" in path and "--verify-tag" in path and "--latest=false" in path
            self.release = {"id": 42, "tag_name": TAG, "draft": True, "prerelease": False,
                "name": path[path.index("--title") + 1], "body": path[path.index("--notes") + 1]}
            return subprocess.CompletedProcess(path, 0, "https://github.com/example/Traetoppen/releases/tag/v1.2.3\n", "")
        if verb == "upload":
            assert self.release["draft"], "uploads must only touch a confirmed draft"
            assert "--clobber" not in path
            name = Path(path[4]).name
            assert not any(asset["name"] == name for asset in self.assets)
            self.assets.append(self.asset(name))
            return subprocess.CompletedProcess(path, 0, "", "")
        raise AssertionError(f"Unexpected gh invocation: {command}")

    def asset(self, name):
        file = self.dist / name
        return {"id": len(self.assets) + 100, "name": name, "state": "uploaded",
            "size": file.stat().st_size, "digest": "sha256:" + release.sha256(file)}


class PublishingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="traetoppen-publish-api-test-")
        self.addCleanup(temporary.cleanup)
        self.dist = Path(temporary.name)
        self.digests = {}
        with mock.patch("builtins.print"):
            for platform in release.PACKAGES:
                for name in release.package_names(TAG, platform):
                    file = self.dist / name
                    file.write_bytes(name.encode())
                    release.record(file, mock.Mock(version="1.2.3", platform=platform), False, "test")
                self.digests.update(release.digests(self.dist, "1.2.3", platform))
        self.files = release.verify_publish(self.dist, TAG, self.digests)
        self.remote = GitHubFixture(self.dist)
        path = ROOT / "tools/release/publish_release.py"
        self.assertTrue(path.exists(), "Missing safe rerunnable Python publisher")
        spec = importlib.util.spec_from_file_location("publish_release", path)
        assert spec is not None and spec.loader is not None
        self.publisher = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.publisher)

    def publish(self):
        with mock.patch.object(self.publisher.subprocess, "run", self.remote.run):
            return self.publisher.publish(self.dist, TAG, REPO, self.digests)

    def existing(self, *, draft=True, count=0):
        self.remote.release = {"id": 42, "tag_name": TAG, "draft": draft, "prerelease": False,
            "name": "Precreated release", "body": "Old notes"}
        self.remote.assets = [self.remote.asset(name) for name in self.files[:count]]
        self.remote.latest = None if draft else 42

    def test_existing_empty_published_release_is_hidden_before_uploads(self):
        self.existing(draft=False)
        self.publish()
        self.assertEqual(len(self.remote.assets), 9)
        self.assertEqual(self.remote.latest, 42)
        self.assertFalse(any(event[0] == "create" for event in self.remote.events))
        edits = [event[2] for event in self.remote.events if event[0] == "PATCH"]
        self.assertEqual(edits[0], {"draft": True, "make_latest": "false"})
        self.assertEqual(edits[-1]["make_latest"], "true")

    def test_complete_matching_release_rerun_does_not_hide_or_write(self):
        self.publish()
        self.remote.events.clear()
        self.publish()
        self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
        self.assertEqual(self.remote.latest, 42)
        self.assertFalse(self.remote.release["draft"])

    def test_interrupted_partial_draft_upload_resumes_only_missing_assets(self):
        self.existing(count=3)
        original = copy.deepcopy(self.remote.assets)
        self.publish()
        self.assertEqual(self.remote.assets[:3], original)
        self.assertEqual(len([event for event in self.remote.events if event[0] == "upload"]), 6)
        self.assertFalse(any(event[0] == "create" for event in self.remote.events))
        self.assertEqual(self.remote.latest, 42)

    def test_release_metadata_is_rechecked_before_promotion(self):
        def change_tag(event):
            if event[0] == "GET" and "/assets?" in event[1] and len(self.remote.assets) == 9:
                self.remote.release["tag_name"] = "v9.9.9"
        self.remote.hook = change_tag
        with self.assertRaises(ValueError):
            self.publish()
        self.assertIsNone(self.remote.latest)
        self.assertTrue(self.remote.release["draft"])
        self.assertFalse(any(event[0] == "PATCH" for event in self.remote.events))

    def test_upload_failure_leaves_a_draft_and_rerun_reconciles_remote_state(self):
        def interrupted(event):
            if event[0] == "upload" and len(self.remote.assets) == 2:
                # GitHub accepted this upload but the CLI lost the response.
                self.remote.assets.append(self.remote.asset(Path(event[1][4]).name))
                return subprocess.CompletedProcess([], 1, "", "connection reset")
        self.remote.hook = interrupted
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertEqual(len(self.remote.assets), 3)
        self.assertTrue(self.remote.release["draft"])
        self.assertIsNone(self.remote.latest)
        self.remote.hook = None
        self.remote.events.clear()
        self.publish()
        self.assertEqual(len([event for event in self.remote.events if event[0] == "upload"]), 6)
        self.assertEqual(self.remote.latest, 42)

    def test_conflicting_unknown_duplicate_and_unverifiable_assets_are_not_overwritten(self):
        cases = [
            {"digest": "sha256:" + "0" * 64}, {"digest": None}, {"size": 0},
            {"state": "starter"}, {"name": "unrelated.zip"}, {"name": "../outside"},
        ]
        for change in cases + ["duplicate"]:
            with self.subTest(change=change):
                self.existing(count=1)
                if change == "duplicate":
                    self.remote.assets.append(copy.deepcopy(self.remote.assets[0]))
                else:
                    self.remote.assets[0].update(change)
                original = copy.deepcopy(self.remote.assets)
                self.remote.events.clear()
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertEqual(self.remote.assets, original)
                self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
                self.assertIsNone(self.remote.latest)

    def test_api_auth_network_and_bad_responses_never_create_a_release(self):
        failures = [response({"message": "Bad credentials"}, 401),
            response({"message": "Forbidden"}, 403), response({"message": "rate limited"}, 429),
            response({"message": "server failure"}, 500),
            subprocess.CompletedProcess([], 1, "", "network error mentions HTTP 404"),
            subprocess.CompletedProcess([], 0, "not an HTTP response", ""),
            subprocess.CompletedProcess([], 0, "HTTP/2.0 200 OK\n\ninvalid JSON", "")]
        for failure in failures:
            for target in (BASE, f"{BASE}/releases/tags/{TAG}", f"{BASE}/releases?per_page=100&page=1"):
                with self.subTest(status=failure.stdout[:30], target=target):
                    self.remote.events.clear()
                    self.remote.hook = lambda event: failure if event[1] == target else None
                    with self.assertRaises((RuntimeError, ValueError)):
                        self.publish()
                    self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
                    self.assertIsNone(self.remote.release)
        self.remote.hook = lambda event: response({"message": "Not Found"}, 404) if event[1] == BASE else None
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertIsNone(self.remote.release)

    def test_successful_invalid_tag_release_response_stops_before_discovery_or_writes(self):
        for value in (None, {}, [], {"message": "Not Found"}, [{"id": 42}], False, "missing"):
            with self.subTest(value=value):
                self.remote = GitHubFixture(self.dist)
                target = f"{BASE}/releases/tags/{TAG}"
                self.remote.hook = lambda event: response(value) if event[1] == target else None
                with self.assertRaisesRegex(ValueError, "release metadata"):
                    self.publish()
                self.assertEqual([event[:2] for event in self.remote.events], [
                    ("GET", BASE), ("GET", f"{BASE}/git/ref/tags/{TAG}"), ("GET", target)])
                self.assertIsNone(self.remote.release)
                self.assertEqual(self.remote.assets, [])

    def test_invalid_discovery_rows_fail_closed_before_any_remote_write(self):
        valid = {"id": 1000, "tag_name": "other-tag", "draft": False, "prerelease": True}
        invalid = [{}, {"id": 1000}, {"message": "Not Found"}, None, [], "release", 42]
        invalid += [{key: value for key, value in valid.items() if key != missing}
                    for missing in valid]
        invalid += [dict(valid, id=value) for value in (None, 0, -1, True, False, "1000", 1.5)]
        invalid += [dict(valid, tag_name=value) for value in (None, 123, False, [], {})]
        invalid += [dict(valid, **{flag: value}) for flag in ("draft", "prerelease")
                    for value in (None, 0, 1, "false", [], {})]
        for page in (1, 2):
            for existing_draft in (False, True):
                for row in invalid:
                    with self.subTest(page=page, existing_draft=existing_draft, row=row):
                        self.remote = GitHubFixture(self.dist)
                        if existing_draft:
                            self.existing(count=3)
                        original = copy.deepcopy((self.remote.release, self.remote.assets))
                        target = f"{BASE}/releases?per_page=100&page={page}"
                        rows = [valid, row]
                        if existing_draft:
                            rows.insert(0, copy.deepcopy(self.remote.release))
                        def malformed_page(event):
                            if event[1] == target:
                                return response(rows)
                            if page == 2 and event[1] == f"{BASE}/releases?per_page=100&page=1":
                                return response([dict(valid, id=1000 + index) for index in range(100)])
                        self.remote.hook = malformed_page
                        with self.assertRaises(ValueError) as failure:
                            self.publish()
                        self.assertTrue(all(event[0] == "GET" for event in self.remote.events),
                                        self.remote.events)
                        self.assertIn("release discovery response", str(failure.exception))
                        self.assertEqual(self.remote.events[-1][:2], ("GET", target))
                        self.assertEqual((self.remote.release, self.remote.assets), original)
                        self.assertIsNone(self.remote.latest)

    def test_valid_varied_discovery_rows_allow_existing_or_new_target_release(self):
        rows = [{"id": index + 1000, "tag_name": tag, "draft": draft, "prerelease": prerelease}
                for index, (tag, draft, prerelease) in enumerate([
                    ("nightly", False, True), ("release/older", True, False),
                    ("v0.1.0", False, False), ("", True, True)])]
        for existing_draft in (False, True):
            with self.subTest(existing_draft=existing_draft):
                self.remote = GitHubFixture(self.dist)
                if existing_draft:
                    self.existing(count=3)
                def varied_page(event):
                    if event[1] == f"{BASE}/releases?per_page=100&page=1":
                        return response(rows + ([self.remote.release] if self.remote.release else []))
                self.remote.hook = varied_page
                self.assertEqual(self.publish(), 42)
                self.assertEqual(self.remote.latest, 42)
                self.assertEqual(sum(event[0] == "create" for event in self.remote.events),
                                 0 if existing_draft else 1)

    def test_discovered_target_prerelease_is_rejected_before_writes(self):
        self.existing(count=3)
        self.remote.release["prerelease"] = True
        original = copy.deepcopy((self.remote.release, self.remote.assets))
        with self.assertRaisesRegex(ValueError, "release metadata"):
            self.publish()
        self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
        self.assertEqual((self.remote.release, self.remote.assets), original)

    def test_successful_invalid_discovered_release_readback_never_creates_or_writes(self):
        for value in (None, {}, [], {"message": "Not Found"},
                      {"id": 99, "tag_name": TAG, "draft": True, "prerelease": False}):
            with self.subTest(value=value):
                self.remote = GitHubFixture(self.dist)
                self.existing(count=3)
                original = copy.deepcopy((self.remote.release, self.remote.assets))
                target = f"{BASE}/releases/42"
                self.remote.hook = lambda event: response(value) if event[1] == target else None
                with self.assertRaisesRegex(ValueError, "release metadata"):
                    self.publish()
                self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
                self.assertEqual(self.remote.events[-1][:2], ("GET", target))
                self.assertEqual((self.remote.release, self.remote.assets), original)

    def test_successful_invalid_repository_preflight_stops_before_tag_lookup_or_writes(self):
        for value in (None, {}, [], {"message": "Not Found"}, {"id": 123},
                      {"full_name": "other/Traetoppen"}, {"full_name": None}, {"full_name": 123}):
            with self.subTest(value=value):
                self.remote = GitHubFixture(self.dist)
                self.remote.hook = lambda event: response(value) if event[1] == BASE else None
                with self.assertRaisesRegex(ValueError, "repository metadata"):
                    self.publish()
                self.assertEqual(self.remote.events, [("GET", BASE, None)])
                self.assertIsNone(self.remote.release)
                self.assertEqual(self.remote.assets, [])

    def test_repository_identity_is_case_insensitive_without_requiring_unused_fields(self):
        self.remote.hook = lambda event: response({"full_name": REPO.swapcase()}) if event[1] == BASE else None
        self.assertEqual(self.publish(), 42)
        self.assertEqual(self.remote.latest, 42)

    def test_successful_invalid_tag_ref_preflight_stops_before_discovery_or_writes(self):
        valid = {"ref": f"refs/tags/{TAG}", "object": {"type": "commit", "sha": "a" * 40}}
        invalid = [None, {}, [], [valid], {"message": "Not Found"},
            dict(valid, ref=f"refs/heads/{TAG}"), dict(valid, ref="refs/tags/v9.9.9"),
            dict(valid, object=None), dict(valid, object=[]), dict(valid, object={}),
            dict(valid, object={"type": "blob", "sha": "a" * 40}),
            dict(valid, object={"type": "commit"}),
            dict(valid, object={"type": "commit", "sha": None}),
            dict(valid, object={"type": "commit", "sha": 123}),
            dict(valid, object={"type": "commit", "sha": "a" * 39}),
            dict(valid, object={"type": "commit", "sha": "g" * 40})]
        for existing_draft in (False, True):
            for value in invalid:
                with self.subTest(existing_draft=existing_draft, value=value):
                    self.remote = GitHubFixture(self.dist)
                    if existing_draft:
                        self.existing(count=3)
                    original = copy.deepcopy((self.remote.release, self.remote.assets))
                    target = f"{BASE}/git/ref/tags/{TAG}"
                    self.remote.hook = lambda event: response(value) if event[1] == target else None
                    with self.assertRaisesRegex(ValueError, "tag reference"):
                        self.publish()
                    self.assertEqual(self.remote.events, [("GET", BASE, None), ("GET", target, None)])
                    self.assertEqual((self.remote.release, self.remote.assets), original)

    def test_tag_ref_preflight_accepts_lightweight_and_annotated_tags(self):
        for kind in ("commit", "tag"):
            with self.subTest(kind=kind):
                self.remote = GitHubFixture(self.dist)
                value = {"ref": f"refs/tags/{TAG}", "object": {"type": kind, "sha": "a" * 40}}
                self.remote.hook = lambda event: response(value) if event[1] == f"{BASE}/git/ref/tags/{TAG}" else None
                self.assertEqual(self.publish(), 42)
                self.assertEqual(self.remote.latest, 42)

    def test_cli_creation_failure_does_not_attempt_upload_or_promotion(self):
        self.remote.hook = lambda event: subprocess.CompletedProcess([], 1, "", "tag missing") if event[0] == "create" else None
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertFalse(any(event[0] in ("upload", "PATCH") for event in self.remote.events))

    def test_command_timeout_fails_closed(self):
        def timeout(event):
            raise subprocess.TimeoutExpired(["gh"], 300)
        self.remote.hook = timeout
        with self.assertRaises(subprocess.TimeoutExpired):
            self.publish()
        self.assertIsNone(self.remote.release)

    def test_demoting_an_empty_published_release_must_succeed_and_persist(self):
        for failure in (response({"message": "Forbidden"}, 403), response({"id": 42})):
            with self.subTest(failure=failure.stdout):
                self.existing(draft=False)
                self.remote.events.clear()
                self.remote.hook = lambda event: failure if event[0] == "PATCH" else None
                with self.assertRaises((RuntimeError, ValueError)):
                    self.publish()
                self.assertFalse(any(event[0] == "upload" for event in self.remote.events))
                self.assertEqual(self.remote.assets, [])

    def test_publish_failure_leaves_verified_draft_ready_to_retry(self):
        self.remote.hook = lambda event: response({"message": "unavailable"}, 503) if event[0] == "PATCH" else None
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertEqual(len(self.remote.assets), 9)
        self.assertTrue(self.remote.release["draft"])
        self.assertIsNone(self.remote.latest)
        self.remote.hook = None
        self.remote.events.clear()
        self.publish()
        self.assertFalse(any(event[0] in ("upload", "create") for event in self.remote.events))
        self.assertEqual(self.remote.latest, 42)

    def test_bad_asset_readback_after_upload_blocks_publication(self):
        for alteration in ("missing", "digest", "extra"):
            with self.subTest(alteration=alteration):
                self.remote = GitHubFixture(self.dist)
                def corrupt(event):
                    if event[0] == "GET" and "/assets?" in event[1] and len(self.remote.assets) == 9:
                        values = copy.deepcopy(self.remote.assets)
                        if alteration == "missing":
                            values.pop()
                        elif alteration == "digest":
                            values[0]["digest"] = None
                        else:
                            values.append(dict(values[0], name="extra.zip"))
                        return response(values)
                self.remote.hook = corrupt
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertIsNone(self.remote.latest)
                self.assertTrue(self.remote.release["draft"])

    def test_postpublish_readbacks_are_required_not_just_successful_patch(self):
        for alteration in ("assets", "metadata", "latest", "api-failure"):
            with self.subTest(alteration=alteration):
                self.remote = GitHubFixture(self.dist)
                def corrupt(event):
                    if self.remote.latest != 42 or event[0] != "GET":
                        return None
                    if alteration == "assets" and "/assets?" in event[1]:
                        return response(self.remote.assets[:-1])
                    if alteration == "metadata" and event[1] == f"{BASE}/releases/42":
                        return response(dict(self.remote.release, body="not persisted"))
                    if alteration == "latest" and event[1].endswith("/latest"):
                        return response(dict(self.remote.release, id=99))
                    if alteration == "api-failure":
                        return response({"message": "bad gateway"}, 502)
                self.remote.hook = corrupt
                with self.assertRaises((ValueError, RuntimeError)):
                    self.publish()

    def test_local_provenance_is_rechecked_before_any_remote_command(self):
        file = self.dist / release.package_names(TAG, "windows")[0]
        file.write_bytes(b"substitution with self-consistent local records")
        with mock.patch("builtins.print"):
            release.record(file, mock.Mock(version="1.2.3", platform="windows"), False, "test")
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.remote.events, [])

    def test_workflow_uses_digest_pinned_python_publisher_after_required_gates(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn("python3 tools/release/publish_release.py", workflow)
        self.assertIn("needs: [version, tests, builds]", workflow)
        self.assertIn("environment: release", workflow)
        self.assertIn("subject-checksums: dist/SHA256SUMS", workflow)
        publish_step = workflow.split("- name: Publish both platforms together after every check passes", 1)[1]
        self.assertIn("needs.builds.outputs.windows", publish_step)
        self.assertIn("needs.builds.outputs.macos", publish_step)
        self.assertNotIn("gh release create", workflow)
        self.assertNotIn("RELEASE_FILES:", workflow)

    def test_existing_draft_without_remote_tag_cannot_publish_or_create_a_tag(self):
        self.existing(count=3)
        self.remote.hook = lambda event: response({"message": "Not Found"}, 404) if event[1] == f"{BASE}/git/ref/tags/{TAG}" else None
        with self.assertRaises(RuntimeError):
            self.publish()
        self.assertTrue(all(event[0] == "GET" for event in self.remote.events))
        self.assertTrue(self.remote.release["draft"])

    def test_generated_release_notes_are_created_once_and_preserved_on_rerun(self):
        def generated_notes(event):
            if event[0] == "create" and "--generate-notes" in event[1]:
                # gh prepends explicit installer notes to GitHub's generated changelog.
                arguments = event[1]
                index = arguments.index("--notes") + 1
                arguments[index] += "\n\n## What's Changed\n* Reviewed feature (#123)\n"
        self.remote.hook = generated_notes
        self.publish()
        self.assertIn("Reviewed feature (#123)", self.remote.release["body"])
        original = self.remote.release["body"]
        self.remote.events.clear()
        self.publish()
        self.assertEqual(self.remote.release["body"], original)
        self.assertTrue(all(event[0] == "GET" for event in self.remote.events))

    def test_existing_partial_published_release_is_hidden_before_resuming(self):
        self.existing(draft=False, count=4)
        original = copy.deepcopy(self.remote.assets)
        self.publish()
        self.assertEqual(self.remote.assets[:4], original)
        self.assertEqual(len([event for event in self.remote.events if event[0] == "upload"]), 5)
        self.assertEqual(self.remote.latest, 42)

    def test_draft_discovery_paginates_and_exhaustion_fails_closed(self):
        self.existing(count=3)
        older = [{"tag_name": "v0.0.1", "id": index + 1000, "draft": False, "prerelease": False}
                 for index in range(100)]
        self.remote.hook = lambda event: response(older) if event[1] == f"{BASE}/releases?per_page=100&page=1" else None
        self.publish()
        self.assertTrue(any(event[1] == f"{BASE}/releases?per_page=100&page=2" for event in self.remote.events))
        self.remote = GitHubFixture(self.dist)
        self.remote.hook = lambda event: response(older) if event[0] == "GET" and "/releases?" in event[1] else None
        with self.assertRaisesRegex(ValueError, "exceeded"):
            self.publish()
        pages = [event for event in self.remote.events if "/releases?" in event[1]]
        self.assertEqual(len(pages), 10)
        self.assertTrue(all(event[0] == "GET" for event in self.remote.events))

    def test_invalid_remote_release_metadata_is_rejected_before_writes(self):
        for change in ({"id": "42"}, {"id": 0}, {"draft": "true"}, {"tag_name": "v2.0.0"}, {"prerelease": True}):
            with self.subTest(change=change):
                self.existing(draft=False)
                self.remote.events.clear()
                invalid = dict(self.remote.release, **change)
                self.remote.hook = lambda event: response(invalid) if event[1] == f"{BASE}/releases/tags/{TAG}" else None
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertTrue(all(event[0] == "GET" for event in self.remote.events))

    def test_cli_accepts_both_build_job_outputs(self):
        arguments = ["publish_release.py", "--tag", TAG, "--repository", REPO, "--dir", str(self.dist)]
        for platform in release.PACKAGES:
            values = {name: self.digests[name] for name in release.package_names(TAG, platform)}
            arguments += ["--digests", json.dumps(values)]
        with mock.patch.object(sys, "argv", arguments), mock.patch.object(self.publisher.subprocess, "run", self.remote.run), mock.patch("builtins.print") as output:
            self.publisher.main()
        output.assert_called_once_with(f"Verified published release 42: {TAG}")
        self.assertEqual(len(self.remote.assets), 9)

    def test_new_release_is_uploaded_as_draft_then_verified_and_promoted(self):
        self.publish()
        self.assertEqual({asset["name"] for asset in self.remote.assets}, set(self.files))
        self.assertFalse(self.remote.release["draft"])
        self.assertFalse(self.remote.release["prerelease"])
        self.assertEqual(self.remote.latest, 42)
        self.assertIn("not notarized", self.remote.release["body"])
        promotion = next(i for i, event in enumerate(self.remote.events) if event[0] == "PATCH" and event[2].get("make_latest") == "true")
        asset_reads = [i for i, event in enumerate(self.remote.events) if event[0] == "GET" and "/assets?" in event[1]]
        self.assertTrue(any(i < promotion for i in asset_reads))
        self.assertTrue(any(i > promotion for i in asset_reads), "remote assets must be re-read after publishing")
        self.assertEqual(self.remote.events[-1][:2], ("GET", f"{BASE}/releases/latest"))


if __name__ == "__main__":
    unittest.main()
