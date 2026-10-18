#!/usr/bin/env python3
"""Prepare reproducible desktop exports and release metadata."""
import argparse
import hashlib
import json
import os
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = re.compile(r"(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\Z")
REPOSITORY = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")
RUNTIME = ("assets", "data", "localization", "lua", "scenes", "scripts", "shaders")


def validate_version(value):
    if not VERSION.fullmatch(value):
        raise ValueError("Version must be X.Y.Z with canonical nonnegative integers")
    return value


def metadata(ref, event):
    production = ref.startswith("refs/tags/")
    version = validate_version(ref.removeprefix("refs/tags/v")) if production else "0.0.0"
    if production and not ref.startswith("refs/tags/v"):
        raise ValueError("Production tags must use vX.Y.Z")
    return {"version": version, "production": str(production).lower(), "tag": "v" + version if production else "", "event": event}


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(command, **options):
    print("Running " + str(command[0]), flush=True)
    subprocess.run([str(x) for x in command], check=True, **options)


def prepare(stage, version, repository, production, platform_name=None):
    validate_version(version)
    if not REPOSITORY.fullmatch(repository):
        raise ValueError("Invalid GitHub owner/repository")
    for folder in RUNTIME:
        if (ROOT / folder).exists():
            shutil.copytree(ROOT / folder, stage / folder, ignore=shutil.ignore_patterns("_user_recordings_v0", "__pycache__"))
    for file in ("project.godot", "export_presets.cfg", "icon.svg", "default_bus_layout.tres"):
        if (ROOT / file).exists():
            shutil.copy2(ROOT / file, stage / file)
    project = (stage / "project.godot").read_text()
    project = project.replace('config/version="0.0.0"', f'config/version="{version}"')
    project = project.replace('repository="magudb/PongPong"', f'repository="{repository}"')
    project = project.replace('channel="development"', 'channel="stable"' if production else 'channel="development"')
    if platform_name == "macos":
        project = project.replace("[rendering]", "[rendering]\ntextures/vram_compression/import_etc2_astc=true")
    (stage / "project.godot").write_text(project)
    presets = (stage / "export_presets.cfg").read_text().replace('"0.0.0.0"', f'"{version}.0"').replace('"0.0.0"', f'"{version}"')
    (stage / "export_presets.cfg").write_text(presets)


def sign_macos(app, work):
    """Credentials are optional; never put them in the exported project or command output."""
    import base64
    certificate = os.environ.get("MACOS_CERTIFICATE_P12", "")
    if not certificate:
        return False
    required = ("MACOS_CERTIFICATE_PASSWORD", "MACOS_SIGNING_IDENTITY", "APPLE_ID", "APPLE_APP_PASSWORD", "APPLE_TEAM_ID")
    if any(not os.environ.get(key) for key in required):
        raise ValueError("macOS signing requires all documented certificate and notarization secrets")
    p12 = work / "certificate.p12"
    p12.write_bytes(base64.b64decode(certificate, validate=True))
    keychain = work / "release.keychain-db"
    password = os.urandom(24).hex()
    try:
        run(["security", "create-keychain", "-p", password, keychain], stdout=subprocess.DEVNULL)
        run(["security", "set-keychain-settings", "-lut", "21600", keychain])
        run(["security", "unlock-keychain", "-p", password, keychain])
        run(["security", "import", p12, "-k", keychain, "-P", os.environ["MACOS_CERTIFICATE_PASSWORD"], "-T", "/usr/bin/codesign"], stdout=subprocess.DEVNULL)
        run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, keychain], stdout=subprocess.DEVNULL)
        run(["codesign", "--force", "--options", "runtime", "--timestamp", "--sign", os.environ["MACOS_SIGNING_IDENTITY"], "--keychain", keychain, app])
        archive = work / "notarize.zip"
        run(["ditto", "-c", "-k", "--keepParent", app, archive])
        run(["xcrun", "notarytool", "submit", archive, "--apple-id", os.environ["APPLE_ID"], "--password", os.environ["APPLE_APP_PASSWORD"], "--team-id", os.environ["APPLE_TEAM_ID"], "--wait"])
        run(["xcrun", "stapler", "staple", app])
        run(["codesign", "--verify", "--deep", "--strict", app])
    finally:
        subprocess.run(["security", "delete-keychain", str(keychain)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        p12.unlink(missing_ok=True)
    return True


def build(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    godot = args.godot or os.environ.get("GODOT", "godot")
    with tempfile.TemporaryDirectory(prefix="traetoppen-export-") as temporary:
        work = Path(temporary)
        stage = work / "project"
        stage.mkdir()
        prepare(stage, args.version, args.repository, args.production, args.platform)
        run([godot, "--headless", "--path", stage, "--import"])
        # A second scan resolves late-bound class names on fresh machines.
        run([godot, "--headless", "--path", stage, "--import"])
        product = work / ("Traetoppen" if args.platform == "windows" else "Traetoppen.app")
        if args.platform == "windows":
            product.mkdir()
            executable = product / "Traetoppen.exe"
        else:
            executable = product
        run([godot, "--headless", "--path", stage, "--export-release", "Windows" if args.platform == "windows" else "macOS", executable])
        signed = sign_macos(product, work) if args.platform == "macos" and os.sys.platform == "darwin" else False
        if args.smoke:
            if args.platform == "windows":
                binary = executable
            else:
                with (product / "Contents/Info.plist").open("rb") as plist:
                    binary_name = plistlib.load(plist)["CFBundleExecutable"]
                if not isinstance(binary_name, str) or Path(binary_name).name != binary_name:
                    raise ValueError("Invalid macOS bundle executable")
                binary = product / "Contents/MacOS" / binary_name
            smoke_report = work / "smoke.json"
            # Keep exported smoke saves/settings separate from the runner's account.
            profile = work / "profile"
            profile.mkdir()
            environment = os.environ.copy()
            environment["HOME"] = str(profile)
            environment["USERPROFILE"] = str(profile)
            environment["APPDATA"] = str(profile / "AppData/Roaming")
            result = subprocess.run([str(binary), "--headless", "--", "--release-smoke", "--report=" + str(smoke_report)], env=environment, cwd=product.parent, timeout=120, capture_output=True, text=True, encoding="utf-8", errors="replace")
            print(result.stdout, flush=True)
            print(result.stderr, flush=True)
            result.check_returncode()
            if re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING):", result.stdout + "\n" + result.stderr, re.MULTILINE):
                raise ValueError("Exported game emitted engine errors or warnings")
            smoke = json.loads(smoke_report.read_text()) if smoke_report.exists() else {}
            if smoke.get("result") != "pass" or smoke.get("version") != args.version or smoke.get("channel") != ("stable" if args.production else "development"):
                raise ValueError("Exported-game smoke check did not pass")
        name = f"Traetoppen-v{args.version}-{args.platform}.zip"
        archive = output / name
        if args.platform == "macos" and os.sys.platform == "darwin":
            run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", product, archive])
        else:
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as package:
                for file in sorted(product.rglob("*")):
                    if file.is_file():
                        package.write(file, file.relative_to(product.parent))
        (output / (name + ".sha256")).write_text(f"{sha256(archive)}  {name}\n")
        (output / (name + ".json")).write_text(json.dumps({"version": args.version, "platform": args.platform, "sha256": sha256(archive), "file": name, "signed_and_notarized": signed}, indent=2) + "\n")
        print(f"Built {archive}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    meta = commands.add_parser("metadata")
    meta.add_argument("--ref", default=os.environ.get("GITHUB_REF", ""))
    meta.add_argument("--event", default=os.environ.get("GITHUB_EVENT_NAME", "local"))
    export = commands.add_parser("build")
    export.add_argument("--platform", choices=("windows", "macos"), required=True)
    export.add_argument("--version", type=validate_version, required=True)
    export.add_argument("--repository", default="magudb/PongPong")
    export.add_argument("--production", action="store_true")
    export.add_argument("--smoke", action="store_true")
    export.add_argument("--godot")
    export.add_argument("--output", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    if args.command == "metadata":
        values = metadata(args.ref, args.event)
        if "GITHUB_OUTPUT" in os.environ:
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as target:
                target.write("".join(f"{key}={value}\n" for key, value in values.items()))
        print(json.dumps(values))
    else:
        build(args)


if __name__ == "__main__":
    main()
