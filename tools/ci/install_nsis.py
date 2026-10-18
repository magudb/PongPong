#!/usr/bin/env python3
"""Install the checksum-pinned, portable NSIS compiler on Windows CI."""
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def install():
    config = json.loads((ROOT / "tools/ci/nsis.json").read_text())
    cache = ROOT / ".godot-bin/downloads"
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / ("nsis-" + config["version"] + ".zip")
    if not archive.exists():
        with urllib.request.urlopen(config["url"], timeout=60) as response:
            data = response.read(33554433)
        if len(data) > 33554432:
            raise ValueError("NSIS toolchain archive exceeds its size limit")
        archive.write_bytes(data)
    with archive.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != config["sha256"]:
        archive.unlink()
        raise ValueError("NSIS toolchain checksum mismatch")
    destination = ROOT / ".godot-bin"
    # Extract only after authenticating the pinned archive, including on cache hits.
    with zipfile.ZipFile(archive) as package:
        package.extractall(destination)
    compiler = destination / ("nsis-" + config["version"]) / "makensis.exe"
    if not compiler.is_file():
        raise ValueError("NSIS archive is missing makensis.exe")
    if "GITHUB_ENV" in os.environ:
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as output:
            output.write("MAKENSIS=" + str(compiler) + "\n")
    print("Verified NSIS " + config["version"] + ": " + str(compiler))


if __name__ == "__main__":
    if sys.platform != "win32":
        raise SystemExit("Use a native makensis installation for cross builds; this installer is for Windows")
    install()
