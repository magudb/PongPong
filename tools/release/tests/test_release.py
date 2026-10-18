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
import zipfile

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("release_tools", ROOT / "tools/release/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class VersionTests(unittest.TestCase):
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

    def test_runtime_exports_preserve_raw_data(self):
        text = (ROOT / "export_presets.cfg").read_text()
        for extension in ("*.lua", "*.csv", "*.json", "*.map", "*.ps1", "*.sh"):
            self.assertIn(extension, text)
        self.assertIn('application/bundle_identifier="io.github.magudb.traetoppen"', text)
        self.assertNotIn("export_presets.cfg", (ROOT / ".gitignore").read_text())


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
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
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
