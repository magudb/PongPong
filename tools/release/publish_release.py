#!/usr/bin/env python3
"""Publish verified desktop assets without overwrites or a partially published latest release."""
import argparse
import json
from pathlib import Path
import re
import subprocess

import release


MISSING = object()  # Only an explicit HTTP 404, never a successful JSON null.


def command(arguments, **options):
    """One bounded, shell-free subprocess seam (also used by the offline API fixtures)."""
    return subprocess.run(["gh", *arguments], capture_output=True, text=True, timeout=300, **options)


class GitHub:
    def __init__(self, repository):
        self.base = "repos/" + repository
        self.repository = repository

    def api(self, path, *, method="GET", payload=None, missing=False):
        arguments = ["api", "--include", "--method", method]
        if payload is not None:
            arguments += ["--input", "-"]
        result = command([*arguments, self.base + path], input=json.dumps(payload) if payload is not None else None)
        # Parse the HTTP response, never localized stderr or a generic CLI exit code.
        header, separator, body = result.stdout.replace("\r\n", "\n").partition("\n\n")
        status = re.match(r"HTTP/\S+ (\d{3})(?: |\n|$)", header)
        code = int(status[1]) if status and separator else None
        if missing and code == 404 and result.returncode:
            return MISSING
        if result.returncode or code is None or not 200 <= code < 300:
            raise RuntimeError(f"GitHub {method} {path} failed (HTTP {code}, exit {result.returncode})")
        return json.loads(body)

    def find_release(self, tag):
        value = self.api("/releases/tags/" + tag, missing=True)
        if value is not MISSING:
            return metadata(value, tag)
        # REST's tag endpoint need not return drafts. List with push access instead.
        # Bound discovery; exhaustion is NOT proof that creating another release is safe.
        for page in range(1, 11):
            values = self.api(f"/releases?per_page=100&page={page}")
            if (not isinstance(values, list) or any(
                    not isinstance(item, dict) or type(item.get("id")) is not int or item["id"] <= 0
                    or not isinstance(item.get("tag_name"), str) or type(item.get("draft")) is not bool
                    or type(item.get("prerelease")) is not bool for item in values)):
                raise ValueError("Invalid release discovery response")
            found = [item for item in values if item.get("tag_name") == tag]
            if len(found) > 1:
                raise ValueError("Ambiguous releases for this tag")
            if found:
                identifier = metadata(found[0], tag)["id"]
                return metadata(self.api(f"/releases/{identifier}"), tag, identifier)
            if len(values) < 100:
                return None
        raise ValueError("Release discovery exceeded 1000 entries; inspect manually")

    def cli(self, *arguments):
        result = command(["release", *arguments, "--repo", self.repository])
        if result.returncode:
            raise RuntimeError(f"gh release {arguments[0]} failed (exit {result.returncode}); rerun after inspection")


def notes(directory, tag):
    mac = json.loads((directory / f"Traetoppen-{tag}-macos.dmg.json").read_text())
    text = [
        "Download the installer for your platform from Assets below.", "",
        f"- **Windows x86_64:** run `Traetoppen-{tag}-windows-setup.exe`. Setup installs for your account, adds a Start menu shortcut and an Apps & Features uninstall entry. A desktop shortcut is optional.",
        f"- **macOS Intel / Apple Silicon:** open `Traetoppen-{tag}-macos.dmg`, drag Traetoppen.app to Applications, then eject the disk image. For a personal installation, use ~/Applications.",
        "- **Updates:** Settings → Updates downloads and installs newer releases after confirmation. Saves are preserved.", "",
        "The ZIP files are update payloads and remain available for existing portable installations.", "",
    ]
    if not mac["signed_and_notarized"]:
        text += ["The macOS build is ad-hoc signed and **not notarized**. See the [macOS installation guidance](https://docs.godotengine.org/en/stable/tutorials/export/running_on_macos.html) if macOS blocks its first launch.", ""]
    return "\n".join(text)


def metadata(value, tag, identifier=None):
    if (not isinstance(value, dict) or type(value.get("id")) is not int or value["id"] <= 0
            or value.get("tag_name") != tag or type(value.get("draft")) is not bool
            or value.get("prerelease") is not False or (identifier is not None and value["id"] != identifier)):
        raise ValueError("Unexpected remote release metadata")
    return value


def assets(github, identifier, expected, *, complete=False):
    values = github.api(f"/releases/{identifier}/assets?per_page=100")
    if not isinstance(values, list):
        raise ValueError("Invalid remote asset list")
    found = set()
    for asset in values:
        name = asset.get("name") if isinstance(asset, dict) else None
        if (name not in expected or name in found or asset.get("state") != "uploaded"
                or asset.get("digest") != expected[name]["digest"]
                or type(asset.get("size")) is not int or asset["size"] != expected[name]["size"]):
            raise ValueError(f"Conflicting or unverifiable remote asset: {name}")
        found.add(name)
    if complete and found != set(expected):
        raise ValueError("Remote release is missing required assets")
    return found


def publish(directory, tag, repository, digests):
    release.validate_tag(tag)
    if not release.REPOSITORY.fullmatch(repository):
        raise ValueError("Invalid GitHub owner/repository")
    directory = directory.resolve()
    files = release.verify_publish(directory, tag, digests, manifest_exists=(directory / "SHA256SUMS").exists())
    expected = {name: {"digest": "sha256:" + release.sha256(directory / name), "size": (directory / name).stat().st_size} for name in files}
    title, body = "Trætoppen " + tag, notes(directory, tag)
    github = GitHub(repository)
    # A hidden/private repository's 404 must not be mistaken for a missing release.
    remote_repository = github.api("")
    if (not isinstance(remote_repository, dict) or not isinstance(remote_repository.get("full_name"), str)
            or remote_repository["full_name"].casefold() != repository.casefold()):
        raise ValueError("Unexpected remote repository metadata")
    # Publishing a pre-existing draft must not implicitly create a missing tag either.
    reference = github.api("/git/ref/tags/" + tag)
    target = reference.get("object") if isinstance(reference, dict) else None
    if (not isinstance(reference, dict) or reference.get("ref") != "refs/tags/" + tag
            or not isinstance(target, dict) or target.get("type") not in ("commit", "tag")
            or not isinstance(target.get("sha"), str) or not re.fullmatch(r"[0-9a-fA-F]{40}", target["sha"])):
        raise ValueError("Unexpected remote tag reference")
    value = github.find_release(tag)
    if value is None:
        github.cli("create", tag, "--draft", "--verify-tag", "--latest=false", "--prerelease=false",
                   "--generate-notes", "--title", title, "--notes", body)
        value = github.find_release(tag)
        if not metadata(value, tag)["draft"]:
            raise ValueError("New release was not created as a draft")
    value = metadata(value, tag)
    # Keep GitHub's generated changelog suffix stable across retries.
    if isinstance(value.get("body"), str) and value["body"].startswith(body):
        body = value["body"]
    identifier = value["id"]
    found = assets(github, identifier, expected)
    complete = found == set(expected)
    if not value["draft"] and not complete:
        github.api(f"/releases/{identifier}", method="PATCH", payload={"draft": True, "make_latest": "false"})
        value = metadata(github.api(f"/releases/{identifier}"), tag, identifier)
        if not value["draft"]:
            raise ValueError("Existing release could not be hidden before uploading")
    for name in files:
        if name not in found:
            # No --clobber: a concurrent conflicting upload must stop this run.
            github.cli("upload", tag, str(directory / name))
    assets(github, identifier, expected, complete=True)
    value = metadata(github.api(f"/releases/{identifier}"), tag, identifier)
    if value["draft"] or value.get("name") != title or value.get("body") != body:
        github.api(f"/releases/{identifier}", method="PATCH", payload={
            "draft": False, "prerelease": False, "make_latest": "true", "name": title, "body": body})
    final = metadata(github.api(f"/releases/{identifier}"), tag, identifier)
    if final["draft"] or final.get("name") != title or final.get("body") != body:
        raise ValueError("Published release metadata did not persist")
    assets(github, identifier, expected, complete=True)
    metadata(github.api("/releases/latest"), tag, identifier)
    return identifier


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--dir", type=Path, required=True)
    parser.add_argument("--digests", action="append", required=True)
    args = parser.parse_args()
    expected = {}
    for value in args.digests:
        expected.update(json.loads(value))
    identifier = publish(args.dir, args.tag, args.repository, expected)
    print(f"Verified published release {identifier}: {args.tag}")


if __name__ == "__main__":
    main()
