import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/release"))
spec = importlib.util.spec_from_file_location("release_tools", ROOT / "tools/release/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class VersionTests(unittest.TestCase):
    def test_partial_macos_signing_configuration_is_rejected(self):
        keys = ("MACOS_CERTIFICATE_P12", "MACOS_CERTIFICATE_PASSWORD", "MACOS_SIGNING_IDENTITY", "APPLE_ID", "APPLE_APP_PASSWORD", "APPLE_TEAM_ID")
        with tempfile.TemporaryDirectory() as temporary:
            for only in ("APPLE_ID", "MACOS_CERTIFICATE_P12"):
                with self.subTest(secret=only), mock.patch.dict(os.environ, {key: "incomplete" if key == only else "" for key in keys}):
                    with self.assertRaises(ValueError), release.macos_signing(Path(temporary)):
                        self.fail("Partly configured signing must not produce an unsigned installer")

    def test_production_tag(self):
        self.assertEqual(release.metadata("refs/tags/v12.34.56", "push")["version"], "12.34.56")
        self.assertEqual(release.metadata("refs/tags/v0.1.0", "push")["production"], "true")

    def test_invalid_tags_never_publish(self):
        for tag in ("v1.2.3-beta", "v1.2.3.4", "v01.2.3", "v1.2", "v1.2.3\n", "1.2.3", "v9999999999.2.3"):
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release.metadata("refs/tags/" + tag, "push")

    def test_branch_cannot_enable_production(self):
        values = release.metadata("refs/heads/v1.2.3", "push")
        self.assertEqual(values["production"], "false")
        self.assertEqual(values["version"], "0.0.0")

    def test_production_tag_must_point_at_main(self):
        with tempfile.TemporaryDirectory() as temporary:
            repository = Path(temporary)
            def git(*command):
                return subprocess.run(["git", "-C", str(repository), "-c", "user.name=Test", "-c", "user.email=test@example.com", *command], check=True, capture_output=True, text=True).stdout.strip()
            git("init", "-q", "-b", "main")
            git("commit", "-q", "--allow-empty", "-m", "reviewed")
            reviewed = git("rev-parse", "HEAD")
            git("switch", "-q", "-c", "unreviewed")
            git("commit", "-q", "--allow-empty", "-m", "unreviewed")
            unreviewed = git("rev-parse", "HEAD")
            release.require_released_from(reviewed, "main", repository)
            for commit in (unreviewed, "0" * 40):
                with self.subTest(commit=commit), self.assertRaises(ValueError):
                    release.require_released_from(commit, "main", repository)

    def test_release_workflow_gates_publishing(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn("--require-on origin/main", workflow)
        self.assertIn("environment: release", workflow)
        self.assertNotIn("secrets: inherit", workflow)

    def test_runtime_exports_preserve_raw_data(self):
        text = (ROOT / "export_presets.cfg").read_text()
        for extension in ("*.lua", "*.csv", "*.json", "*.map", "*.ps1", "*.sh"):
            self.assertIn(extension, text)
        self.assertIn('application/bundle_identifier="io.github.magudb.traetoppen"', text)
        self.assertNotIn("export_presets.cfg", (ROOT / ".gitignore").read_text())

    def test_release_exports_leave_test_tools_out(self):
        text = (ROOT / "export_presets.cfg").read_text()
        filters = [line for line in text.splitlines() if line.startswith("exclude_filter=")]
        self.assertEqual(len(filters), 2)
        for line in filters:
            for pattern in ("scenes/ui/cheat_menu.tscn", "scripts/ui/testing/*", "scripts/dungeon/gen/dungeon_verify.gd"):
                self.assertIn(pattern, line)
        self.assertNotIn("cheats", "".join(line for line in text.splitlines() if line.startswith("custom_features=")))


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="traetoppen-publish-test-")
        self.dist = Path(self.directory.name)
        self.digests = {}
        for platform_name in ("windows", "macos"):
            args = mock.Mock(version="1.2.3", platform=platform_name)
            for name in release.package_names("v1.2.3", platform_name):
                package = self.dist / name
                package.write_bytes(name.encode())
                release.record(package, args, False, "test")
            self.digests.update(release.digests(self.dist, "1.2.3", platform_name))

    def tearDown(self):
        self.directory.cleanup()

    def test_matching_artifacts_publish_with_job_digests(self):
        files = release.verify_publish(self.dist, "v1.2.3", self.digests)
        self.assertEqual(len(files), 9)
        self.assertFalse(any(name.endswith(".sha256") for name in files))
        self.assertEqual((self.dist / "SHA256SUMS").read_text(), "".join(f"{self.digests[name]}  {name}\n" for name in sorted(self.digests)))

    def test_rechecking_generated_manifest_preserves_exact_inputs(self):
        files = release.verify_publish(self.dist, "v1.2.3", self.digests)
        self.assertEqual(release.verify_publish(self.dist, "v1.2.3", self.digests, manifest_exists=True), files)
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", self.digests)
        (self.dist / "SHA256SUMS").write_text("substituted manifest\n")
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", self.digests, manifest_exists=True)

    def test_substituted_package_with_its_own_checksums_is_refused(self):
        # A replacement that carries a self-consistent .sha256 and .json record must still fail.
        package = self.dist / "Traetoppen-v1.2.3-windows.zip"
        package.write_bytes(b"substituted")
        release.record(package, mock.Mock(version="1.2.3", platform="windows"), False, "test")
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", self.digests)

    def test_extra_or_missing_files_are_refused(self):
        (self.dist / "Traetoppen-v1.2.3-linux.zip").write_bytes(b"extra")
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", self.digests)
        (self.dist / "Traetoppen-v1.2.3-linux.zip").unlink()
        (self.dist / "Traetoppen-v1.2.3-macos.dmg.json").unlink()
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", self.digests)

    def test_one_platform_digest_is_not_enough(self):
        windows_only = {name: digest for name, digest in self.digests.items() if "windows" in name}
        with self.assertRaises(ValueError):
            release.verify_publish(self.dist, "v1.2.3", windows_only)

    def test_release_workflow_downloads_exact_artifacts(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertNotIn("pattern:", workflow)
        self.assertNotIn("merge-multiple", workflow)
        self.assertIn("verify-publish", workflow)


def ci_sections():
    spec = importlib.util.spec_from_file_location("ci_sections", ROOT / "tools/ci/sections.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class CoverageTests(unittest.TestCase):
    def test_ci_shards_run_every_section_exactly_once(self):
        module = ci_sections()
        expected = {p.stem for p in (ROOT / "tests/sections").glob("*.gd") if not p.name.startswith("_")}
        groups = module.partitions(4)
        all_sections = [name for group in groups for name in group]
        self.assertTrue(all(groups))
        self.assertEqual(set(all_sections), expected)
        self.assertEqual(len(all_sections), len(expected))
        paced = [name for pace in ("normal", "simulation") for group in module.partitions(4, pace) for name in group]
        self.assertEqual(set(paced), expected)
        self.assertEqual(len(paced), len(expected))
        for invalid in (0, -1, len(expected) + 1):
            with self.assertRaises(ValueError):
                module.partitions(invalid)
        # CI: the hero shards plus the once-only neutral job hold every section exactly once
        hero = [name for pace in ("normal", "simulation") for group in module.partitions(4, pace, hero=True) for name in group]
        self.assertEqual(sorted(hero + sorted(module.NEUTRAL)), sorted(expected))
        self.assertFalse(module.NEUTRAL & module.SIMULATIONS)
        windowed = [name for group in module.windowed_partitions(4) for name in group]
        self.assertEqual(sorted(windowed), module.windowed_names())
        self.assertTrue(set(windowed) <= expected)

    def test_ci_shards_are_balanced_by_time(self):
        module = ci_sections()
        # largest first, each to the lightest shard; a section without a time costs the median (5.5 here)
        groups = module.balance(["a", "b", "c", "d", "e"], 2, {"a": 10.0, "b": 6.0, "c": 5.0, "d": 1.0})
        self.assertEqual(groups, [["a", "c"], ["b", "d", "e"]])
        self.assertEqual(module.balance(["x", "y"], 3, {}), [["x"], ["y"], []])

    def test_neutral_sections_do_not_use_the_hero(self):
        module = ci_sections()
        for call in ("await t.start_world()", "t.character", "t.new_game()", "Fresh.new_game(t)", 'Fresh.new_game(t, "")',
                     'UiAudit.audit_screen(t, "x")', "t.tree.current_scene"):
            self.assertRegex(call, module.HERO_API)
        for call in ('t.check("x", true)', 'Fresh.new_game(t, "animal", "Tester")', "t.run_tool(python, args)"):
            self.assertNotRegex(call, module.HERO_API)
        with mock.patch("builtins.print"):
            self.assertEqual(module.check(), 0)


class ToolchainTests(unittest.TestCase):
    def test_editor_is_the_pinned_executable_in_a_fresh_folder(self):
        sys.path.insert(0, str(ROOT / "tools/ci"))
        spec = importlib.util.spec_from_file_location("ci_install_godot", ROOT / "tools/ci/install_godot.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "editor"
            # A previous pin left its editor behind; it sorts first and is not a console wrapper.
            (root / module.CONFIG["version"]).mkdir(parents=True)
            (root / module.CONFIG["version"] / "Godot_v4.0.0-stable_win64.exe").write_bytes(b"old editor")
            for host in ("windows", "linux"):
                with self.subTest(host=host):
                    name = module.editor_executable(host)
                    archive = Path(temporary) / (host + ".zip")
                    with zipfile.ZipFile(archive, "w") as package:
                        package.writestr(name.replace(".exe", "") + "_console" + (".exe" if name.endswith(".exe") else ""), b"console")
                        package.writestr(name, b"pinned editor")
                    binary = module.extract_editor(archive, root, host)
                    self.assertEqual(binary.name, name)
                    self.assertEqual(binary.read_bytes(), b"pinned editor")
                    self.assertEqual(sorted(p.name for p in binary.parent.iterdir()), sorted(zipfile.ZipFile(archive).namelist()))
            with zipfile.ZipFile(archive, "w") as package:
                package.writestr("Godot_v4.0.0-stable_linux.x86_64", b"wrong version")
            with self.assertRaises(ValueError):
                module.extract_editor(archive, root, "linux")


COMPLETE = {"Traetoppen/Traetoppen.exe": b"new executable", "Traetoppen/Traetoppen.pck": b"new data"}
# The helpers' launch lines and recording stand-ins for them. A stub logs what was launched and what the result
# file said at that moment; the first TT_TEST_LAUNCH_FAILS launches fail.
WINDOWS_LAUNCH = "if (!$NoLaunch) { Start-Process -FilePath (Join-Path $Target 'Traetoppen.exe') -WorkingDirectory $Target }"
WINDOWS_STUB = ("if (!$NoLaunch) { $seen = if (Test-Path -LiteralPath $Result) { (Get-Content -Raw -LiteralPath $Result).Trim() } else { 'none' }; "
                "Add-Content -LiteralPath $env:TT_TEST_LAUNCHES -Value ((Get-Content -Raw -LiteralPath (Join-Path $Target 'Traetoppen.exe')) + '|' + $seen); "
                "if (@(Get-Content -LiteralPath $env:TT_TEST_LAUNCHES).Count -le [int]$env:TT_TEST_LAUNCH_FAILS) { throw 'launch refused' } }")
MACOS_LAUNCH = '/usr/bin/open -n "$target"'
MACOS_STUB = '"$TT_TEST_OPEN" -n "$target"'
MACOS_OPEN = """#!/bin/bash
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$2/Contents/Info.plist")
seen=$(cat "$TT_TEST_RESULT" 2>/dev/null || echo none)
echo "$version|$seen" >> "$TT_TEST_LAUNCHES"
[[ $(wc -l < "$TT_TEST_LAUNCHES") -gt $TT_TEST_LAUNCH_FAILS ]]
"""


class InstallerTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="traetoppen-updater-test-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        # The installation's parent folder; results and archives live outside it, like user data.
        self.games = self.root / "games"
        self.games.mkdir()
        self.addCleanup(self.games.chmod, 0o755)
        self.result = self.root / "result.json"
        self.launches = self.root / "launches.txt"
        self.powershell = shutil.which("pwsh") or shutil.which("powershell")

    def helper(self, name, launch, stub):
        text = (ROOT / "scripts/release" / name).read_text(encoding="utf-8")
        self.assertEqual(text.count(launch), 1, "the helper's launch line changed")
        path = self.root / name
        path.write_text(text.replace(launch, stub), encoding="utf-8")
        return path

    def environment(self, fails):
        return dict(os.environ, TT_TEST_LAUNCHES=str(self.launches), TT_TEST_LAUNCH_FAILS=str(fails), TT_TEST_RESULT=str(self.result), TT_TEST_OPEN=str(self.root / "open"))

    def launched(self):
        """(what was launched, the result file at that moment) for every launch."""
        lines = self.launches.read_text(encoding="utf-8-sig").splitlines() if self.launches.exists() else []
        return [(launched, json.loads(seen) if seen != "none" else None) for launched, seen in (line.split("|", 1) for line in lines)]

    def outcome(self):
        return json.loads(self.result.read_text(encoding="utf-8-sig"))

    def dummy_parent(self):
        """Stands in for the running game: the helper must not touch the installation until it exits."""
        process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
        self.addCleanup(process.wait)
        self.addCleanup(process.kill)
        return process

    def lock(self, target):
        """Holds the installation the way a virus scan does, so the folder cannot be renamed; returns the release."""
        if os.name == "nt":
            handle = (target / "Traetoppen.pck").open("rb")
            self.addCleanup(handle.close)
            return handle.close
        self.games.chmod(0o555)
        return lambda: self.games.chmod(0o755)

    def run_helper(self, command, cwd, fails, parent, before_exit):
        helper = subprocess.Popen(command, cwd=cwd, env=self.environment(fails), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            if parent:
                ready = Path(str(self.result) + ".ready")
                deadline = time.monotonic() + 60
                while not ready.exists() and helper.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertEqual(ready.read_bytes() if ready.exists() else b"", b"ready", "helper never signalled ready")
                time.sleep(0.5)
                self.assertIsNone(helper.poll(), "helper must wait for the game to exit")
                if before_exit:
                    before_exit()
                parent.kill()
                parent.wait()
            stdout, stderr = helper.communicate(timeout=90)
        finally:
            if helper.poll() is None:
                helper.kill()
                helper.wait()
        return subprocess.CompletedProcess(command, helper.returncode, stdout, stderr)

    def windows(self, entries, bad_hash=False, folder="Traetoppen", parent=None, launch=False, fails=0, before_exit=None):
        if not self.powershell:
            self.skipTest("PowerShell is tested on the Windows export runner")
        target = self.games / folder
        target.mkdir(exist_ok=True)
        (target / "Traetoppen.exe").write_bytes(b"previous executable")
        (target / "Traetoppen.pck").write_bytes(b"previous data")
        archive = self.root / "update.zip"
        with zipfile.ZipFile(archive, "w") as package:
            for name, value in entries.items():
                package.writestr(name, value)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        script = self.helper("install_windows.ps1", WINDOWS_LAUNCH, WINDOWS_STUB) if launch else ROOT / "scripts/release/install_windows.ps1"
        command = [self.powershell, "-NoProfile", "-File", str(script), "-ParentProcessId", str(parent.pid if parent else 0), "-Archive", str(archive), "-Target", str(target), "-ExpectedSha", "0" * 64 if bad_hash else digest, "-Result", str(self.result)]
        if not launch:
            command.append("-NoLaunch")
        return self.run_helper(command, target, fails, parent, before_exit and (lambda: before_exit(target))), target

    def test_windows_replaces_complete_package(self):
        result, target = self.windows(COMPLETE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"new executable")
        self.assertEqual(self.outcome(), {"status": "installed", "reason": ""})

    def test_windows_bad_hash_keeps_previous(self):
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"bad"}, bad_hash=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "checksum"})

    def test_windows_update_preserves_setup_uninstaller(self):
        target = self.games / "Traetoppen"
        target.mkdir()
        (target / "Uninstall.exe").write_bytes(b"setup-generated uninstaller")
        result, target = self.windows(COMPLETE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "Uninstall.exe").read_bytes(), b"setup-generated uninstaller")

    def test_windows_missing_data_keeps_previous(self):
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"incomplete"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.pck").read_bytes(), b"previous data")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "package"})

    def test_windows_path_traversal_keeps_previous(self):
        result, target = self.windows({"Traetoppen/../../escaped.txt": b"escape", "Traetoppen/Traetoppen.exe": b"bad"})
        self.assertNotEqual(result.returncode, 0)
        # The helper stages next to the installation, so the member would land in games/.
        self.assertFalse((self.games / "escaped.txt").exists())
        self.assertFalse((self.root / "escaped.txt").exists())
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")
        self.assertEqual(self.outcome()["reason"], "package")

    def test_windows_unexpected_folder_is_refused(self):
        result, target = self.windows(COMPLETE, folder="Game")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "folder"})

    def test_windows_waits_for_the_game_and_reports_before_launching(self):
        result, target = self.windows(COMPLETE, parent=self.dummy_parent(), launch=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launched(), [("new executable", {"status": "installed", "reason": ""})])

    def test_windows_failed_launch_restores_and_relaunches_previous(self):
        result, target = self.windows(COMPLETE, parent=self.dummy_parent(), launch=True, fails=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")
        self.assertEqual((target / "Traetoppen.pck").read_bytes(), b"previous data")
        self.assertEqual(self.outcome(), {"status": "rolled_back", "reason": "launch"})
        self.assertEqual([launched for launched, seen in self.launched()], ["new executable", "previous executable"])
        self.assertEqual(list(self.games.glob(".Traetoppen-update.*")), [])

    def test_windows_retries_a_briefly_locked_installation(self):
        def hold(target):
            release = threading.Timer(1.0, self.lock(target))
            self.addCleanup(release.cancel)
            release.start()
        result, target = self.windows(COMPLETE, parent=self.dummy_parent(), launch=True, before_exit=hold)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"new executable")
        self.assertEqual((target / "Traetoppen.pck").read_bytes(), b"new data")
        self.assertEqual(self.outcome(), {"status": "installed", "reason": ""})
        self.assertEqual(self.launched(), [("new executable", {"status": "installed", "reason": ""})])
        self.assertEqual(list(self.games.glob(".Traetoppen-update.*")), [])

    def test_windows_locked_installation_relaunches_previous(self):
        result, target = self.windows(COMPLETE, parent=self.dummy_parent(), launch=True, before_exit=self.lock)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")
        self.assertEqual((target / "Traetoppen.pck").read_bytes(), b"previous data")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "locked"})
        self.assertEqual(self.launched(), [("previous executable", {"status": "failed", "reason": "locked"})])
        # The non-Windows permission-based lock also prevents removing the staging
        # directory; a native Windows file lock only holds the previous installation.
        if os.name == "nt":
            self.assertEqual(list(self.games.glob(".Traetoppen-update.*")), [])

    def macos(self, bad_hash=False, parent=None, launch=False, fails=0, before_exit=None):
        if sys.platform != "darwin":
            self.skipTest("macOS installer is exercised on macOS")
        target = self.games / "Traetoppen.app"
        replacement = self.root / "incoming/Traetoppen.app"
        for bundle, version in ((target, "0.1.0"), (replacement, "0.2.0")):
            executable = bundle / "Contents/MacOS/Trætoppen"
            executable.parent.mkdir(parents=True)
            shutil.copyfile("/usr/bin/true", executable)
            executable.chmod(0o755)
            with (bundle / "Contents/Info.plist").open("wb") as file:
                plistlib.dump({"CFBundleIdentifier": "io.github.magudb.traetoppen", "CFBundleExecutable": "Trætoppen", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": version}, file)
            subprocess.run(["codesign", "--force", "--sign", "-", str(bundle)], check=True, capture_output=True)
        archive = self.root / "update.zip"
        subprocess.run(["ditto", "-c", "-k", "--keepParent", str(replacement), str(archive)], check=True)
        digest = "0" * 64 if bad_hash else hashlib.sha256(archive.read_bytes()).hexdigest()
        script = ROOT / "scripts/release/install_macos.sh"
        if launch:
            script = self.helper("install_macos.sh", MACOS_LAUNCH, MACOS_STUB)
            stub = self.root / "open"
            stub.write_text(MACOS_OPEN)
            stub.chmod(0o755)
        command = ["/bin/bash", str(script), str(parent.pid if parent else 0), str(archive), str(target), digest, str(self.result)]
        if not launch:
            command.append("--no-launch")
        return self.run_helper(command, self.root, fails, parent, before_exit and (lambda: before_exit(target))), target

    def version(self, bundle):
        with (bundle / "Contents/Info.plist").open("rb") as file:
            return plistlib.load(file)["CFBundleShortVersionString"]

    def test_macos_replaces_signed_bundle(self):
        result, target = self.macos()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.version(target), "0.2.0")
        self.assertEqual(self.outcome(), {"status": "installed", "reason": ""})

    def test_macos_bad_hash_reports_its_reason(self):
        result, target = self.macos(bad_hash=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version(target), "0.1.0")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "checksum"})
        self.assertFalse(Path(str(self.result) + ".ready").exists())
        self.assertEqual(list(self.games.glob(".Traetoppen-update.*")), [])

    def test_macos_waits_for_the_game_and_reports_before_launching(self):
        result, target = self.macos(parent=self.dummy_parent(), launch=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launched(), [("0.2.0", {"status": "installed", "reason": ""})])

    def test_macos_failed_launch_restores_and_relaunches_previous(self):
        result, target = self.macos(parent=self.dummy_parent(), launch=True, fails=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version(target), "0.1.0")
        self.assertEqual(self.outcome(), {"status": "rolled_back", "reason": "launch"})
        self.assertEqual([launched for launched, seen in self.launched()], ["0.2.0", "0.1.0"])
        self.assertEqual(list(self.games.glob(".Traetoppen-update.*")), [])

    def test_macos_retries_a_briefly_locked_installation(self):
        def hold(target):
            release = threading.Timer(1.0, self.lock(target))
            self.addCleanup(release.cancel)
            release.start()
        result, target = self.macos(parent=self.dummy_parent(), launch=True, before_exit=hold)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.version(target), "0.2.0")
        self.assertEqual(self.outcome(), {"status": "installed", "reason": ""})

    def test_macos_locked_installation_relaunches_previous(self):
        result, target = self.macos(parent=self.dummy_parent(), launch=True, before_exit=self.lock)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.version(target), "0.1.0")
        self.assertEqual(self.outcome(), {"status": "failed", "reason": "locked"})
        self.assertEqual(self.launched(), [("0.1.0", {"status": "failed", "reason": "locked"})])


if __name__ == "__main__":
    unittest.main()
