#!/usr/bin/env python3
"""Reject new large binaries and plain blobs on Git LFS paths (REPO-01, docs/DEVELOPMENT.md "Repository size").

    size_guard.py --staged                  pre-commit hook: the blobs staged in the index
    size_guard.py --range BASE..HEAD        CI: every blob a commit of the range adds or changes
    size_guard.py --audit [REV]             no plain blob at REV (default HEAD) sits on an LFS-tracked path

A blob on a path whose `filter` attribute is `lfs` must be a Git LFS pointer (the object it names may be at most
`lfs-object` bytes). Any other blob may be at most the limit of the first allowlist line that matches its path, or
`default` when none does. The allowlist is tools/ci/size_allowlist.txt; unchanged files are never checked. Works in a
blobless partial clone (CI): the blobs to measure are fetched in one batch. Exit code 0 = clean, 1 = violations,
2 = usage or git error. Only the standard library is used.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ALLOWLIST = Path(__file__).resolve().with_name("size_allowlist.txt")
POINTER_MAX = 1024
POINTER_VERSIONS = (b"version https://git-lfs.github.com/spec/v1\n", b"version https://hawser.git-scm.com/spec/v1\n")
UNITS = {"": 1, "B": 1, "K": 1024, "KIB": 1024, "M": 1024 ** 2, "MIB": 1024 ** 2, "G": 1024 ** 3, "GIB": 1024 ** 3}
HINT = """
How to fix (docs/DEVELOPMENT.md, "Repository size"):
  * a raw QA screenshot or a run log does not belong in git: keep a summary or a small crop, upload the rest elsewhere;
  * art and media under docs/ or tools/art/ go through Git LFS: `brew install git-lfs && git lfs install` once, then
    `git rm --cached <file> && git add <file>` stores it as a pointer;
  * a shipped asset or test fixture that really must be larger: raise its line in tools/ci/size_allowlist.txt
    in the same commit, and say why in the commit message."""


class GitError(Exception):
    pass


def git(repo, *args, data=None, env=None):
    result = subprocess.run(["git", "-C", str(repo), *args], input=data, capture_output=True,
                            env={**os.environ, **(env or {})})
    if result.returncode != 0:
        raise GitError("git %s: %s" % (" ".join(args[:2]), result.stderr.decode(errors="replace").strip()))
    return result.stdout


def parse_size(text):
    match = re.fullmatch(r"(\d+)\s*([A-Za-z]*)", text.strip())
    if not match or match.group(2).upper() not in UNITS:
        raise ValueError("bad size %r" % text)
    return int(match.group(1)) * UNITS[match.group(2).upper()]


def glob_regex(pattern):
    """`**` spans directories, `*` and `?` stay inside one path component (as in .gitattributes)."""
    out = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        elif pattern[i] == "?":
            out += "[^/]"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


def load_allowlist(path):
    limits = {"default": None, "lfs-object": None}
    rules = []
    for number, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise ValueError("%s:%d: expected '<size> <pattern>' or '<default|lfs-object> <size>'" % (path, number))
        if parts[0] in limits:
            limits[parts[0]] = parse_size(parts[1])
        else:
            rules.append((parts[1], glob_regex(parts[1]), parse_size(parts[0])))
    if None in limits.values():
        raise ValueError("%s: needs a 'default' and an 'lfs-object' line" % path)
    return limits, rules


def limit_for(path, limits, rules):
    for pattern, regex, limit in rules:
        if regex.match(path):
            return limit, pattern
    return limits["default"], "default"


def split_z(data):
    return data.decode("utf-8", errors="surrogateescape").split("\0")


def raw_entries(tokens):
    """(path, oid) of every A/M/T entry in `--raw -z` output; anything else (commit markers) is skipped."""
    entries = []
    i = 0
    while i < len(tokens):
        head = tokens[i].rsplit("\n", 1)[-1]
        if head.startswith(":"):
            fields = head[1:].split()
            if fields[1] not in ("160000", "000000") and fields[4][0] in "AMT":
                entries.append((tokens[i + 1], fields[3]))
            i += 2
        else:
            i += 1
    return entries


def staged_entries(repo):
    try:
        base = git(repo, "rev-parse", "--verify", "-q", "HEAD").decode().strip()
    except GitError:
        base = git(repo, "hash-object", "-t", "tree", "--stdin", data=b"").decode().strip()
    return raw_entries(split_z(git(repo, "diff", "--cached", "--raw", "-z", "--no-renames", "--no-abbrev",
                                   "--diff-filter=AMT", base)))


def range_entries(repo, span):
    if ".." not in span or span.startswith("..") or span.endswith(".."):
        raise GitError("--range needs BASE..HEAD, got %r" % span)
    out = git(repo, "log", "--raw", "-z", "--no-renames", "--no-abbrev", "--diff-filter=AMT",
              "--diff-merges=first-parent", "--format=tformat:%x01%H", span, "--")
    return raw_entries(split_z(out))


def tree_entries(repo, rev):
    entries = []
    for token in split_z(git(repo, "ls-tree", "-r", "-z", "--full-tree", rev)):
        if token:
            meta, path = token.split("\t", 1)
            _, kind, oid = meta.split()
            if kind == "blob":
                entries.append((path, oid))
    return entries


def attributes(repo, paths, source):
    """{path: (filter, plain-blob)} from the index's attributes, or from those of the tree `source`."""
    if not paths:
        return {}
    where = ["--cached"] if source is None else ["--source=" + source]
    tokens = split_z(git(repo, "check-attr", "-z", "--stdin", *where, "filter", "plain-blob",
                         data="\0".join(paths).encode("utf-8", errors="surrogateescape") + b"\0"))
    found = {path: ["unspecified", "unspecified"] for path in paths}
    for i in range(0, len(tokens) - 2, 3):
        found[tokens[i]][0 if tokens[i + 1] == "filter" else 1] = tokens[i + 2]
    return {path: (value[0], value[1] == "set") for path, value in found.items()}


def prefetch(repo, oids):
    """In a partial clone, fetch the missing blobs in one request instead of one lazy fetch per blob."""
    promisor = subprocess.run(["git", "-C", str(repo), "config", "--get", "extensions.partialclone"],
                              capture_output=True, text=True).stdout.strip()
    if not promisor or not oids:
        return
    out = git(repo, "cat-file", "--batch-check", data="\n".join(oids).encode() + b"\n", env={"GIT_NO_LAZY_FETCH": "1"})
    missing = [line.split()[0] for line in out.decode().splitlines() if line.endswith(" missing")]
    if missing:
        git(repo, "-c", "fetch.negotiationAlgorithm=noop", "fetch", promisor, "--no-tags", "--no-write-fetch-head",
            "--recurse-submodules=no", "--filter=blob:none", "--stdin", data="\n".join(missing).encode() + b"\n")


def sizes(repo, oids):
    out = git(repo, "cat-file", "--batch-check=%(objectname) %(objectsize)", data="\n".join(oids).encode() + b"\n")
    return {oid: int(size) for oid, size in (line.split() for line in out.decode().splitlines())}


def pointer_size(repo, oid):
    """The object size a Git LFS pointer names, or None when the blob is not a pointer."""
    text = git(repo, "cat-file", "blob", oid)
    if not text.startswith(POINTER_VERSIONS):
        return None
    match = re.search(rb"^size (\d+)$", text, re.M)
    return int(match.group(1)) if match else None


def human(size):
    if size >= 10 * 1024 ** 2 or (size >= 1024 ** 2 and size % 1024 ** 2 == 0):
        return "%.4g MiB" % (size / 1024 ** 2)
    return "%d KiB" % (size // 1024) if size >= 1024 else "%d B" % size


def check(repo, entries, source, limits, rules, audit=False):
    pairs = sorted(set(entries))
    attrs = attributes(repo, sorted({path for path, _ in pairs}), source)
    if audit:
        pairs = [(path, oid) for path, oid in pairs if attrs[path][0] == "lfs"]
    wanted = sorted({oid for _, oid in pairs})
    prefetch(repo, wanted)
    size = sizes(repo, wanted) if wanted else {}
    problems = []
    for path, oid in pairs:
        lfs_filter, grandfathered = attrs[path]
        if lfs_filter == "lfs":
            target = pointer_size(repo, oid) if size[oid] < POINTER_MAX else None
            if target is None and audit:
                problems.append("%s: plain %s blob on a Git LFS path (narrow the LFS pattern, or store the file in LFS)"
                                % (path, human(size[oid])))
            elif target is None:
                problems.append("%s: plain %s blob on a Git LFS path (git-lfs is not installed here?)"
                                % (path, human(size[oid])))
            elif target > limits["lfs-object"]:
                problems.append("%s: LFS object of %s is over the %s lfs-object limit"
                                % (path, human(target), human(limits["lfs-object"])))
        else:
            limit, rule = limit_for(path, limits, rules)
            if size[oid] > limit:
                note = "; grandfathered: delete its line in the nearest .gitattributes to store it in LFS" \
                    if grandfathered and rule == "default" else ""
                problems.append("%s: %s is over the %s limit (%s%s)" % (path, human(size[oid]), human(limit), rule, note))
    return sorted(set(problems)), len(pairs)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--staged", action="store_true", help="check the blobs staged in the index")
    mode.add_argument("--range", metavar="BASE..HEAD", help="check every blob the commits of the range add or change")
    mode.add_argument("--audit", nargs="?", const="HEAD", metavar="REV", help="check that LFS paths hold pointers only")
    parser.add_argument("--repo", default=".", help="repository (default: the current directory)")
    parser.add_argument("--allowlist", default=str(ALLOWLIST), help="limits file (default: %(default)s)")
    args = parser.parse_args(argv)
    try:
        limits, rules = load_allowlist(args.allowlist)
        if args.staged:
            entries, source, what = staged_entries(args.repo), None, "staged files"
        elif args.range:
            tip = args.range.split("..")[-1].lstrip(".")
            entries, source, what = range_entries(args.repo, args.range), tip, "commits " + args.range
        else:
            entries, source, what = tree_entries(args.repo, args.audit), args.audit, "tree " + args.audit
        problems, checked = check(args.repo, entries, source, limits, rules, audit=args.audit is not None)
    except (GitError, ValueError, OSError) as error:
        print("size_guard: %s" % error, file=sys.stderr)
        return 2
    if problems:
        print("size_guard: %d blob(s) in the %s break the repository size policy:" % (len(problems), what), file=sys.stderr)
        for problem in problems:
            print("  " + problem, file=sys.stderr)
        print(HINT, file=sys.stderr)
        return 1
    if args.audit:
        print("size_guard: all %d blob(s) on Git LFS paths in the %s are pointers" % (checked, what))
    else:
        print("size_guard: %d blob(s) in the %s are within the policy" % (checked, what))
    return 0


if __name__ == "__main__":
    sys.exit(main())
