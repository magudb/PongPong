#!/usr/bin/env python3
"""Appends the feature autoloads to [autoload] of project.godot - the ONLY sanctioned edit of project.godot outside package P01 (addendum exception E1).

    python3 tools/features/add_autoload.py [--project FILE] [--root DIR] [--dry-run] [NAME ...]

NAME is one of HomeManager FurnitureManager WardrobeManager LootService CollectionLog SocialManager (default: all six).  Each owner package runs this tool as its LAST task
(F2 HomeManager, F3 FurnitureManager, F5 WardrobeManager, F4 LootService, F9 CollectionLog, S-core SocialManager), so packages of one wave never edit the file by hand and a missing script can never break boot.
The list is CLOSED: a seventh name needs this CONTRACT, tools/features/test_add_autoload.py NAMES, tests/lib/features/fresh.gd FEATURE_NODES and tests/tools/check_project.gd FEATURE_AUTOLOADS widened together
(the self-test compares CONTRACT, NAMES and FEATURE_NODES with each other; check_project.gd is P01's file and carries its own pin).

Rules (all enforced, none of them optional):
  * a line is appended only when its script file exists (scripts/<dir>/<name>.gd under --root, default = the folder of the project file) and the entry is absent;
  * it goes AFTER AnimalHusbandry, behind the entries already there (the base block and earlier feature lines stay byte for byte as they were);
  * idempotent: a second run, or a run for an entry that is already there with its contract path, changes nothing (exit 0, "already present");
  * a name given twice on the command line is added once (exactly one line per autoload);
  * an entry that exists with ANOTHER path or twice, an unknown name, a missing [autoload] section, a missing AnimalHusbandry line or a foreign entry behind the base block makes the tool REFUSE (exit 3): it never repairs or rewrites anything else;
  * a --project that is not an existing file (or a --root that is not a directory) is REFUSED (exit 3) before anything is opened or created: no traceback, no stray lock file; a project file that cannot
    be read as UTF-8 text or written is REFUSED the same way (exit 3);
  * parallel runs are safe: an exclusive flock on `project.godot.lock` (next to the project file, gitignored) is held over read - modify - write, and the new file replaces the old one by an atomic rename;
  * after writing, the tool re-reads the file and proves that the only difference to the old text is the added lines (otherwise it restores nothing and exits 3 BEFORE the rename).
Exit codes: 0 ok / nothing to do, 2 usage, 3 refused.
"""
from __future__ import annotations
import argparse
import fcntl
import os
import re
import stat
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
# name -> contract path of the autoload line (addendum 3.2; tests/tools/check_project.gd FEATURE_AUTOLOADS accepts exactly these)
CONTRACT = {
    'HomeManager': 'scripts/home/home_manager.gd',
    'FurnitureManager': 'scripts/furniture/furniture_manager.gd',
    'WardrobeManager': 'scripts/wardrobe/wardrobe_manager.gd',
    'LootService': 'scripts/loot/loot_service.gd',
    'CollectionLog': 'scripts/collection/collection_log.gd',
    'SocialManager': 'scripts/social/social_manager.gd',          # the sixth (towns / farm / social addendum DT17, fix round RT2)
}
ENTRY = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)="(\*?)res://([^"]+)"\s*$')


class Refused(Exception):
    pass


def section_bounds(lines: list[str]) -> tuple[int, int]:
    """(index of the line after `[autoload]`, index of the first line of the next section or len)"""
    start = next((i for i, ln in enumerate(lines) if ln.strip() == '[autoload]'), None)
    if start is None:
        raise Refused('project.godot has no [autoload] section')
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('[')), len(lines))
    return start + 1, end


def plan(text: str, names: list[str], root: Path) -> tuple[str, list[str]]:
    """returns (new text, report lines); raises Refused"""
    lines = text.split('\n')
    a, b = section_bounds(lines)
    entries = [(i, ENTRY.match(lines[i])) for i in range(a, b) if lines[i].strip() and not lines[i].lstrip().startswith(';')]
    for i, m in entries:
        if m is None:
            raise Refused(f'line {i + 1} of the [autoload] section is not an autoload entry: {lines[i]!r}')
    names_here = [m.group(1) for _, m in entries]
    twice = sorted(n for n in set(names_here) if n in CONTRACT and names_here.count(n) > 1)
    if twice:
        raise Refused(f'{", ".join(twice)} appears more than once in [autoload]: the tool never repairs a file, remove the extra line by hand')
    if 'AnimalHusbandry' not in names_here:
        raise Refused('AnimalHusbandry is not in [autoload]: the base block of P01 is missing, refusing to append behind nothing')
    last_base = names_here.index('AnimalHusbandry')
    for n in names_here[last_base + 1:]:
        if n not in CONTRACT:
            raise Refused(f'unexpected autoload {n} behind AnimalHusbandry (only the {len(CONTRACT)} feature autoloads of the contract may follow)')
    report = []
    insert_after = entries[-1][0]                      # behind the last entry (base block + feature lines already there)
    add: list[str] = []
    for n in dict.fromkeys(names):                     # a name given twice is one name: exactly one line per autoload
        want = f'*res://{CONTRACT[n]}'
        have = [m for _, m in entries if m.group(1) == n]
        if have:
            got = f'{have[0].group(2)}res://{have[0].group(3)}'
            if got != want:
                raise Refused(f'{n} is already registered with another path ({got}, contract {want})')
            report.append(f'already present {n}')
            continue
        if not (root / CONTRACT[n]).is_file():
            report.append(f'skipped {n}: {CONTRACT[n]} does not exist yet')
            continue
        add.append(f'{n}="{want}"')
        report.append(f'added {n}')
    if not add:
        return text, report
    new_lines = lines[:insert_after + 1] + add + lines[insert_after + 1:]
    return '\n'.join(new_lines), report


def prove_only_additions(old: str, new: str, added: int) -> None:
    ol, nl = old.split('\n'), new.split('\n')
    if len(nl) != len(ol) + added:
        raise Refused('internal check: the new text has an unexpected number of lines')
    j = 0
    for ln in ol:
        while j < len(nl) and nl[j] != ln:
            j += 1
        if j >= len(nl):
            raise Refused('internal check: an old line is missing in the new text')
        j += 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--project', default=str(REPO / 'project.godot'))
    ap.add_argument('--root', help='folder the script paths are checked against (default: the folder of --project)')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('names', nargs='*')
    a = ap.parse_args()
    names = list(dict.fromkeys(a.names or list(CONTRACT)))
    bad = [n for n in names if n not in CONTRACT]
    if bad:
        print(f'unknown autoload name(s) {bad}; allowed: {list(CONTRACT)}', file=sys.stderr)
        return 2
    project = Path(a.project).resolve()
    root = Path(a.root).resolve() if a.root else project.parent
    # refuse BEFORE the lock file is opened: open(lock, 'a+') would create a stray lock next to a project that does not exist (or fail with a traceback in a folder that does not exist)
    if not project.is_file():
        print(f'REFUSED: --project {a.project} is not an existing file', file=sys.stderr)
        return 3
    if not root.is_dir():
        print(f'REFUSED: --root {a.root} is not a directory', file=sys.stderr)
        return 3
    lock_path = project.with_name('project.godot.lock') if project.name == 'project.godot' else project.with_name(project.name + '.lock')
    try:
        lock = open(lock_path, 'a+')
    except OSError as e:
        print(f'REFUSED: cannot open the lock file {lock_path}: {e}', file=sys.stderr)
        return 3
    with lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            old = project.read_text(encoding='utf-8')
            new, report = plan(old, names, root)
            for r in report:
                print(r)
            added = sum(1 for r in report if r.startswith('added '))
            if added and not a.dry_run:
                prove_only_additions(old, new, added)
                fd, tmp = tempfile.mkstemp(prefix=project.name + '.', suffix='.tmp', dir=str(project.parent))
                try:
                    with os.fdopen(fd, 'w', encoding='utf-8', newline='') as f:
                        f.write(new)
                        f.flush()
                        os.fsync(f.fileno())
                    os.chmod(tmp, stat.S_IMODE(project.stat().st_mode))
                    os.replace(tmp, project)
                except BaseException:
                    if os.path.exists(tmp):
                        os.unlink(tmp)
                    raise
        except Refused as e:
            print(f'REFUSED: {e}', file=sys.stderr)
            return 3
        except (OSError, UnicodeDecodeError) as e:              # unreadable / not text / not writable: a refusal with the documented exit code, never a traceback, the file is as it was
            print(f'REFUSED: {project} cannot be read or written: {e}', file=sys.stderr)
            return 3
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
    return 0


if __name__ == '__main__':
    sys.exit(main())
