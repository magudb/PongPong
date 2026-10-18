"""Native distribution packages and real install/update/uninstall checks."""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
UNINSTALL_KEY = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Traetoppen"


def run(command, **options):
    print("Running " + Path(command[0]).name, flush=True)
    return subprocess.run([str(value) for value in command], check=True, **options)


def sha256(file):
    with file.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def windows(product, output, version, repository, compiler=None):
    compiler = compiler or os.environ.get("MAKENSIS") or shutil.which("makensis")
    if not compiler:
        raise ValueError("NSIS is required: run python tools/ci/install_nsis.py on Windows, or install NSIS for cross builds")
    prefix = "/" if os.name == "nt" else "-"
    definitions = {"SOURCE_DIR": product, "OUTPUT": output, "VERSION": version, "REPOSITORY": repository,
                   "SIZE_KB": sum(file.stat().st_size for file in product.iterdir() if file.is_file()) // 1024}
    run([compiler, prefix + "WX", prefix + "INPUTCHARSET", "UTF8",
         *[prefix + "D" + name + "=" + str(value) for name, value in definitions.items()],
         ROOT / "tools/release/windows.nsi"])


def macos(product, output, work):
    contents = work / "disk-image"
    contents.mkdir()
    run(["ditto", product, contents / product.name])
    (contents / "Applications").symlink_to("/Applications")
    (contents / "Install.txt").write_text(
        "Trætoppen\n\nDrag Traetoppen.app onto Applications, then eject this disk image.\n"
        "Open the installed app from Applications.\n"
        "For an installation just for you, copy it to ~/Applications instead.\n\n"
        "Settings > Updates installs new releases after confirmation.\n"
        "Updating needs a writable installation folder; saves stay in your user-data folder.\n", encoding="utf-8")
    run(["hdiutil", "create", "-volname", "Trætoppen", "-srcfolder", contents,
         "-format", "UDZO", "-ov", output])


def smoke_macos(image, archive, work, smoke_game):
    run(["hdiutil", "verify", image])
    mount = work / "mounted-installer"
    mount.mkdir()
    run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, image])
    try:
        if os.readlink(mount / "Applications") != "/Applications":
            raise ValueError("DMG is missing its Applications installation shortcut")
        installed = work / "installed/Applications/Traetoppen.app"
        installed.parent.mkdir(parents=True)
        run(["ditto", mount / "Traetoppen.app", installed])
    finally:
        run(["hdiutil", "detach", mount])
    with (installed / "Contents/Info.plist").open("rb") as source:
        executable = plistlib.load(source)["CFBundleExecutable"]
    architectures = run(["lipo", "-archs", installed / "Contents/MacOS" / executable], capture_output=True, text=True).stdout.split()
    if set(architectures) != {"x86_64", "arm64"}:
        raise ValueError("macOS installer must contain Intel and Apple Silicon architectures")
    # Exercise the same folder replacement used by the in-game updater after a DMG install.
    marker = installed / "previous-installation"
    marker.write_text("must disappear after update")
    digest = sha256(archive)
    run(["bash", ROOT / "scripts/release/install_macos.sh", "0", archive, installed,
         digest, work / "installed-update.json", "--no-launch"])
    if marker.exists():
        raise ValueError("Update did not replace the DMG-installed application")
    run(["codesign", "--verify", "--deep", "--strict", installed])
    smoke_game(installed, work / "installed-smoke")


def smoke_windows(installer, archive, work, version, smoke_game):
    if sys.platform != "win32":
        raise ValueError("Windows installer smoke checks must run on Windows")
    import winreg
    import ctypes
    view = winreg.KEY_READ | winreg.KEY_WOW64_64KEY
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY, 0, view):
            raise ValueError("Installer smoke check refuses to modify an existing Trætoppen installation")
    except FileNotFoundError:
        pass
    programs = ctypes.create_unicode_buffer(32768)
    if ctypes.windll.shell32.SHGetFolderPathW(None, 2, None, 0, programs) != 0:
        raise ValueError("Could not locate the current user's Start menu")
    shortcut = Path(programs.value) / "Trætoppen.lnk"
    if shortcut.exists():
        raise ValueError("Installer smoke check refuses to replace an existing Trætoppen shortcut")
    installed = work / "installed game/Traetoppen"
    # NSIS requires its final /D= argument without quotes, even when the path has spaces.
    command = subprocess.list2cmdline([str(installer), "/S"]) + " /D=" + str(installed)
    subprocess.run(command, check=True, timeout=180)
    try:
        if not shortcut.is_file():
            raise ValueError("Windows installer did not create its Start menu shortcut")
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY, 0, view) as key:
            if winreg.QueryValueEx(key, "InstallLocation")[0] != str(installed) or winreg.QueryValueEx(key, "DisplayVersion")[0] != version:
                raise ValueError("Windows installation registration is incorrect")
        uninstaller = installed / "Uninstall.exe"
        previous = uninstaller.read_bytes()
        digest = sha256(archive)
        run(["powershell.exe", "-NoProfile", "-File", ROOT / "scripts/release/install_windows.ps1",
             "-ParentProcessId", "0", "-Archive", archive, "-Target", installed,
             "-ExpectedSha", digest, "-Result", work / "installed-update.json", "-NoLaunch"])
        if uninstaller.read_bytes() != previous:
            raise ValueError("In-game update removed or changed the Windows uninstaller")
        smoke_game(installed, work / "installed-smoke")
    finally:
        uninstaller = installed / "Uninstall.exe"
        if uninstaller.exists():
            canary = installed / "player-file.keep"
            canary.write_text("not owned by the installer")
            command = subprocess.list2cmdline([str(uninstaller), "/S"]) + " _?=" + str(installed)
            subprocess.run(command, check=True, timeout=180)
            if (installed / "Traetoppen.exe").exists() or (installed / "Traetoppen.pck").exists() or not canary.exists():
                raise ValueError("Windows uninstall failed or removed files it does not own")
            if shortcut.exists():
                raise ValueError("Windows uninstall left its Start menu shortcut behind")
            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY, 0, view):
                    raise ValueError("Windows uninstall left its Apps & Features entry behind")
            except FileNotFoundError:
                pass
