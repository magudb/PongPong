#!/usr/bin/env python3
"""Install the pinned official engine and, optionally, desktop export templates."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import tempfile
import urllib.request
import zipfile

from template_archive import RangeArchive

ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "tools/ci/godot.json").read_text())


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def download(key, cache):
    record = CONFIG["archives"][key]
    path = cache / record["name"]
    cache.mkdir(parents=True, exist_ok=True)
    if path.exists() and digest(path) == record["sha256"]:
        return path
    url = f'https://github.com/godotengine/godot/releases/download/{CONFIG["version"]}-stable/{record["name"]}'
    temporary = path.with_suffix(".download")
    print(f"Downloading {record['name']}", flush=True)
    probe = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
    with urllib.request.urlopen(probe, timeout=120) as source:
        total = int(source.headers.get("Content-Range", "0/0").split("/")[-1]) if source.status == 206 else 0
    if total > 32 * 1024 * 1024:
        # Desktop templates include mobile platforms. Concurrent ranges avoid a single slow CDN stream.
        with tempfile.TemporaryDirectory(prefix="godot-parts-", dir=cache) as folder:
            chunk = 16 * 1024 * 1024
            parts = list(range(0, total, chunk))

            def fetch(start):
                end = min(start + chunk, total) - 1
                request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
                path = Path(folder) / str(start)
                with urllib.request.urlopen(request, timeout=180) as response, path.open("wb") as target:
                    if response.status != 206 or response.headers.get("Content-Range") != f"bytes {start}-{end}/{total}":
                        raise ValueError("Unexpected download range")
                    shutil.copyfileobj(response, target, 1024 * 1024)
                if path.stat().st_size != end - start + 1:
                    raise ValueError("Truncated download range")

            with ThreadPoolExecutor(max_workers=8) as workers:
                list(workers.map(fetch, parts))
            with temporary.open("wb") as target:
                for start in parts:
                    with (Path(folder) / str(start)).open("rb") as source:
                        shutil.copyfileobj(source, target, 1024 * 1024)
    else:
        with urllib.request.urlopen(url, timeout=120) as source, temporary.open("wb") as target:
            shutil.copyfileobj(source, target, 1024 * 1024)
    if digest(temporary) != record["sha256"]:
        raise ValueError(f"SHA-256 mismatch: {record['name']}")
    temporary.replace(path)
    return path


def template_dir():
    if platform.system() == "Darwin":
        data = Path.home() / "Library/Application Support"
    elif platform.system() == "Windows":
        data = Path(os.environ["APPDATA"])
    else:
        data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return data / "Godot" / "export_templates" / (CONFIG["version"] + ".stable") if platform.system() in ("Darwin", "Windows") else data / "godot/export_templates" / (CONFIG["version"] + ".stable")


def editor_executable(host):
    """The member that holds the editor, named exactly by the pinned archive (never the console wrapper)."""
    if host == "macos":
        return "Godot.app/Contents/MacOS/Godot"
    return CONFIG["archives"][host]["name"].removesuffix(".zip")


def extract_editor(archive, root, host):
    # A fresh folder per version: an old editor left by a previous pin can never be picked.
    destination = root / CONFIG["version"]
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    member = editor_executable(host)
    with zipfile.ZipFile(archive) as source:
        if member not in source.namelist():
            raise ValueError(f"Pinned archive has no {member}")
        source.extractall(destination)
    binary = destination / member
    binary.chmod(binary.stat().st_mode | 0o111)
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=ROOT / ".godot-bin/downloads")
    parser.add_argument("--templates", action="store_true")
    parser.add_argument("--templates-only", action="store_true")
    args = parser.parse_args()
    host = {"Linux": "linux", "Darwin": "macos", "Windows": "windows"}[platform.system()]
    if not args.templates_only:
        archive = download(host, args.cache)
        binary = extract_editor(archive, ROOT / ".godot-bin/editor", host)
        if "GITHUB_ENV" in os.environ:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as env:
                env.write(f"GODOT={binary.resolve()}\n")
        print(f"GODOT={binary.resolve()}")
    if args.templates or args.templates_only:
        destination = template_dir()
        destination.mkdir(parents=True, exist_ok=True)
        # Mobile templates dominate the upstream archive. Fetch desktop members only,
        # checking each extracted member against a committed SHA-256 pin.
        cache = args.cache / "desktop-templates"
        cache.mkdir(parents=True, exist_ok=True)
        missing = [name for name, expected in CONFIG["desktop_templates"].items()
                   if not (cache / name).exists() or digest(cache / name) != expected]
        if missing:
            record = CONFIG["archives"]["templates"]
            url = f'https://github.com/godotengine/godot/releases/download/{CONFIG["version"]}-stable/{record["name"]}'
            with RangeArchive(url) as remote, zipfile.ZipFile(remote) as source:
                for name in missing:
                    print(f"Downloading desktop template {name}", flush=True)
                    member = source.getinfo("templates/" + name)
                    if max(member.file_size, member.compress_size) > 256 * 1024 * 1024:
                        raise ValueError("Unexpected desktop template size")
                    temporary = cache / (name + ".download")
                    try:
                        # Reading one bounded member lets RangeArchive parallelize its ranges.
                        temporary.write_bytes(source.read(member))
                        if digest(temporary) != CONFIG["desktop_templates"][name]:
                            raise ValueError(f"SHA-256 mismatch: {name}")
                        temporary.replace(cache / name)
                    finally:
                        temporary.unlink(missing_ok=True)
        for name in CONFIG["desktop_templates"]:
            shutil.copyfile(cache / name, destination / name)
        print(f"Export templates: {destination}")


if __name__ == "__main__":
    main()
