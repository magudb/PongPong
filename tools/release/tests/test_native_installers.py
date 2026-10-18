import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/release"))
import native_installers as installers


class NativeInstallerTests(unittest.TestCase):
    def test_windows_setup_compiles(self):
        compiler = os.environ.get("MAKENSIS") or shutil.which("makensis")
        if not compiler:
            self.skipTest("NSIS compilation runs on the Windows export runner")
        with tempfile.TemporaryDirectory(prefix="native-installer-test-") as temporary:
            root = Path(temporary)
            product = root / "game files/Traetoppen"
            product.mkdir(parents=True)
            (product / "Traetoppen.exe").write_bytes(b"fixture executable")
            (product / "Traetoppen.pck").write_bytes(b"fixture data")
            output = root / "Traetoppen-v1.2.3-windows-setup.exe"
            installers.windows(product, output, "1.2.3", "magudb/PongPong", compiler)
            with output.open("rb") as source:
                self.assertEqual(source.read(2), b"MZ")

    @unittest.skipUnless(sys.platform == "darwin", "Disk images are exercised on macOS")
    def test_dmg_install_and_update_signed_universal_app(self):
        with tempfile.TemporaryDirectory(prefix="native-installer-test-") as temporary:
            root = Path(temporary)
            product = root / "Traetoppen.app"
            executable = product / "Contents/MacOS/Trætoppen"
            executable.parent.mkdir(parents=True)
            source = root / "main.c"
            source.write_text("int main(void) { return 0; }\n")
            subprocess.run(["cc", "-arch", "x86_64", "-arch", "arm64", "-mmacosx-version-min=11.0", str(source), "-o", str(executable)], check=True, capture_output=True)
            with (product / "Contents/Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier":"io.github.magudb.traetoppen", "CFBundleExecutable":"Trætoppen", "CFBundleShortVersionString":"1.2.3", "CFBundleVersion":"1.2.3", "CFBundlePackageType":"APPL"}, output)
            subprocess.run(["codesign", "--force", "--sign", "-", str(product)], check=True, capture_output=True)
            archive = root / "update.zip"
            subprocess.run(["ditto", "-c", "-k", "--keepParent", str(product), str(archive)], check=True)
            image = root / "installer.dmg"
            installers.macos(product, image, root)
            boots = []

            def boot(installed, smoke_work):
                binary = installed / "Contents/MacOS/Trætoppen"
                subprocess.run([str(binary)], check=True)
                boots.append(installed)

            installers.smoke_macos(image, archive, root, boot)
            self.assertEqual(len(boots), 1)


if __name__ == "__main__":
    unittest.main()
