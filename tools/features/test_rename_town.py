#!/usr/bin/env python3
"""Self-test of rename_town.py on COPIES in a temp dir (never the repo).  Prints one `PASS <id>` / `FAIL <id>` line per check (tests/lib/t.gd expect_tool_ids reads them;
tests/sections/content_features.gd runs this file as `content_features.rename_town_*`).  The retired town name is built from parts here: it is never written in this repository.

    python3 -I tools/features/test_rename_town.py

Checks (review F1 r2, fix round 2)
  refuses_empty_old_with_apply            --old '' --apply exits 2 and leaves every file byte for byte as it was (it used to rewrite every text file: 'abc' became 15 copies of the new name and a second run grew it exponentially)
  refuses_blank_old                       ' ', a tab, a padded name and a name shorter than 3 characters exit 2 without touching anything (dry run too)
  refuses_empty_new                       --new '' exits 2
  dry_run_changes_nothing                 without --apply the files are untouched and the hits are listed
  apply_renames_all_case_variants         Old -> New, OLD -> NEW, old -> new, the genitive keeps its s, an id (area_<old>) and a CSV key (FIND_AREA_<OLD>) follow
  covers_map_svg_tscn_tres_gdshader       the text maps of the area framework (.map), vector art (.svg), scenes (.tscn), resources (.tres) and shaders are rewritten (.map / .svg were skipped)
  leaves_binary_and_skip_dirs             a .png, a file under .git and under .venv, and a file named "Style Guide ..." are not touched
  second_apply_is_noop                    a second --apply finds nothing
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE / 'rename_town.py'
OLD = 'Fes' + 'by'                                         # the retired town name, built from parts
fails = 0


def check(cid, ok, detail=''):
    global fails
    print(('PASS ' if ok else 'FAIL ') + cid + (f'  ({detail})' if detail and not ok else ''), flush=True)
    fails += 0 if ok else 1


def run(*args):
    return subprocess.run([sys.executable, '-I', str(TOOL), *args], capture_output=True, text=True)


def write(p: Path, text: str, mode='w'):
    p.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(text, bytes):
        p.write_bytes(text)
    else:
        p.write_text(text, encoding='utf-8')


def snapshot(root: Path) -> dict:
    return {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(root.rglob('*')) if p.is_file()}


def main() -> int:
    with tempfile.TemporaryDirectory(prefix='rename_t.') as d:
        root = Path(d) / 'repo'
        write(root / 'lua' / 'a.lua', f'area = "{OLD.lower()}"\n-- {OLD}s market, {OLD.upper()}\n')
        write(root / 'localization' / 'finds.csv', f'keys,da,en\nFIND_AREA_{OLD.upper()},"{OLD}","{OLD}"\n')
        write(root / 'plain' / 'abc.txt', 'abc\n')
        before = snapshot(root)

        # --- the guards: nothing is read or written, exit 2
        r = run('--old', '', '--apply', str(root))
        check('refuses_empty_old_with_apply', r.returncode == 2 and snapshot(root) == before and 'refused' in r.stderr, f'exit {r.returncode} {r.stderr.strip()[:100]}')
        r_all = [run('--old', o, '--apply', str(root)) for o in (' ', '   ', '\t', 'ab', f' {OLD}', f'{OLD} ')] + [run('--old', ' ', str(root))]
        check('refuses_blank_old', all(x.returncode == 2 for x in r_all) and snapshot(root) == before, str([x.returncode for x in r_all]))
        r = run('--old', OLD, '--new', '', '--apply', str(root))
        check('refuses_empty_new', r.returncode == 2 and snapshot(root) == before, f'exit {r.returncode}')

        # --- dry run
        r = run('--old', OLD, str(root))
        check('dry_run_changes_nothing', r.returncode == 0 and snapshot(root) == before and 'dry run' in r.stdout and 'a.lua' in r.stdout and 'finds.csv' in r.stdout, r.stdout[-200:])

        # --- the variants
        r = run('--old', OLD, '--apply', str(root))
        lua = (root / 'lua' / 'a.lua').read_text(encoding='utf-8')
        csv = (root / 'localization' / 'finds.csv').read_text(encoding='utf-8')
        ok = r.returncode == 0 and 'area = "hyggebyen"' in lua and 'Hyggebyens market' in lua and 'HYGGEBYEN' in lua and 'FIND_AREA_HYGGEBYEN,"Hyggebyen","Hyggebyen"' in csv \
            and OLD.lower() not in (lua + csv).lower() and (root / 'plain' / 'abc.txt').read_text() == 'abc\n'
        check('apply_renames_all_case_variants', ok, lua + csv)
        r2 = run('--old', OLD, '--apply', str(root))
        check('second_apply_is_noop', r2.returncode == 0 and '0 files' in r2.stdout and (root / 'lua' / 'a.lua').read_text(encoding='utf-8') == lua, r2.stdout[-120:])

        # --- the text formats that used to be skipped, and the things that must stay alone
        root2 = Path(d) / 'repo2'
        texts = {'data/maps/town.map': f'name {OLD}\narea {OLD.lower()}\n', 'assets/icon.svg': f'<svg><title>{OLD}</title></svg>\n', 'scenes/main/world.tscn': f'[node name="{OLD}Gate"]\n',
                 'assets/ui/theme.tres': f'name = "{OLD.lower()}_theme"\n', 'shaders/x.gdshader': f'// {OLD}\n', 'docs/Style Guide notes.md': f'{OLD} stays in the design export\n'}
        for rel, text in texts.items():
            write(root2 / rel, text)
        write(root2 / 'assets' / 'p.png', OLD.encode() + b'\x89PNG\x00\xff')
        write(root2 / '.git' / 'HEAD.md', f'{OLD}\n')
        write(root2 / 'tools' / 'art' / '.venv' / 'lib.py', f'x = "{OLD}"\n')
        before2 = snapshot(root2)
        r = run('--old', OLD, '--apply', str(root2))
        after2 = snapshot(root2)
        converted = [rel for rel in ('data/maps/town.map', 'assets/icon.svg', 'scenes/main/world.tscn', 'assets/ui/theme.tres', 'shaders/x.gdshader') if OLD.lower() not in after2[rel].decode().lower() and b'yggebyen' in after2[rel]]
        check('covers_map_svg_tscn_tres_gdshader', r.returncode == 0 and len(converted) == 5, f'converted {converted}; {r.stdout[-160:]}')
        untouched = [rel for rel in ('assets/p.png', '.git/HEAD.md', 'tools/art/.venv/lib.py', 'docs/Style Guide notes.md') if after2[rel] == before2[rel]]
        check('leaves_binary_and_skip_dirs', len(untouched) == 4, f'untouched {untouched}')
    print(f"test_rename_town: {'PASS' if not fails else 'FAIL'} ({fails} failing check(s))")
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
