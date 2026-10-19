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


class CoverageTests(unittest.TestCase):
    def test_ci_shards_run_every_section_exactly_once(self):
        spec = importlib.util.spec_from_file_location("ci_sections", ROOT / "tools/ci/sections.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
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


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="traetoppen-updater-test-")
        self.root = Path(self.directory.name)
        self.result = self.root / "result.json"
        self.powershell = shutil.which("pwsh") or shutil.which("powershell")

    def tearDown(self):
        self.directory.cleanup()

    def windows(self, entries, bad_hash=False):
        if not self.powershell:
            self.skipTest("PowerShell is tested on the Windows export runner")
        target = self.root / "Traetoppen"
        target.mkdir(exist_ok=True)
        (target / "Traetoppen.exe").write_bytes(b"previous executable")
        (target / "Traetoppen.pck").write_bytes(b"previous data")
        archive = self.root / "update.zip"
        with zipfile.ZipFile(archive, "w") as package:
            for name, value in entries.items():
                package.writestr(name, value)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        command = [self.powershell, "-NoProfile", "-File", str(ROOT / "scripts/release/install_windows.ps1"), "-ParentProcessId", "0", "-Archive", str(archive), "-Target", str(target), "-ExpectedSha", "0" * 64 if bad_hash else digest, "-Result", str(self.result), "-NoLaunch"]
        result = subprocess.run(command, cwd=target, capture_output=True, text=True, timeout=30)
        return result, target

    def test_windows_replaces_complete_package(self):
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"new executable", "Traetoppen/Traetoppen.pck": b"new data"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"new executable")
        self.assertEqual(json.loads(self.result.read_text(encoding="utf-8-sig"))["status"], "installed")

    def test_windows_bad_hash_keeps_previous(self):
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"bad"}, bad_hash=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")

    def test_windows_update_preserves_setup_uninstaller(self):
        target = self.root / "Traetoppen"
        target.mkdir()
        (target / "Uninstall.exe").write_bytes(b"setup-generated uninstaller")
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"new executable", "Traetoppen/Traetoppen.pck": b"new data"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((target / "Uninstall.exe").read_bytes(), b"setup-generated uninstaller")

    def test_windows_missing_data_keeps_previous(self):
        result, target = self.windows({"Traetoppen/Traetoppen.exe": b"incomplete"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "Traetoppen.pck").read_bytes(), b"previous data")

    def test_windows_path_traversal_keeps_previous(self):
        result, target = self.windows({"Traetoppen/../../escaped.txt": b"escape", "Traetoppen/Traetoppen.exe": b"bad"})
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root.parent / "escaped.txt").exists())
        self.assertEqual((target / "Traetoppen.exe").read_bytes(), b"previous executable")

    @unittest.skipUnless(sys.platform == "darwin", "macOS installer is exercised on macOS")
    def test_macos_replaces_signed_bundle(self):
        target = self.root / "Traetoppen.app"
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
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        result = subprocess.run(["bash", str(ROOT / "scripts/release/install_macos.sh"), "0", str(archive), str(target), digest, str(self.result), "--no-launch"], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        with (target / "Contents/Info.plist").open("rb") as file:
            self.assertEqual(plistlib.load(file)["CFBundleShortVersionString"], "0.2.0")


if __name__ == "__main__":
    unittest.main()
