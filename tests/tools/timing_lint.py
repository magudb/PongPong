#!/usr/bin/env python3
"""Timing lint of the playtest sections (TEST-02, TEST-03): prints one PASS/FAIL line per rule.

  raw_wall_clock_budgets   a check / expect that limits a wall-clock measurement from above (`ms <= 0.4`) outside
                           t.perf_ok(): a difference of Time.get_ticks_usec() / get_ticks_msec() readings or a timing
                           the game measured itself (`area.build_ms`, `nav.bake_us`, `last_tick_usec`)
  frame_count_waits        a `for i in N:` loop of single frames that gives up with t.fail(): a frame count is
                           no bound for anything the game animates by its delta (use t.until_game())
  lint_detects_mutants     the rules flag the built-in bad samples and none of the good ones

A wall-clock comparison that is not a budget (a wait that has to end well before its own timeout) carries
`# raw-time-ok: <reason>` on the line of the check. The analysis is textual and per top-level function: a variable is
a measurement when it is assigned, appended or iterated from an expression that is one. The harness's own tests
(tests/lib/selftest) time the harness itself and are not scanned. The policy: the header of tests/lib/t.gd.

  python3 tests/tools/timing_lint.py [--verbose] [ROOT]
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TICKS = re.compile(r"\bTime\.get_ticks_(?:usec|msec)\(\)")
ASSIGN = re.compile(r"^\s*(?:var\s+)?([A-Za-z_]\w*)\s*(?::\s*[\w\[\]]+\s*)?(?::=|=|\+=|-=)\s*(.+)$")
APPEND = re.compile(r"\b([A-Za-z_]\w*)\.(?:append|push_back)\((.+)\)")
CHECK = re.compile(r"\b(?:t\.check|t\.expect|_check|_judge)\(")
LOOP_VAR = re.compile(r"^\s*for\s+([A-Za-z_]\w*)\s+in\s+(.+):\s*$")
GAME_TIMING = re.compile(r"\.\w*_(?:ms|usec|us)\b")
EXEMPT = "# raw-time-ok:"
FRAME_LOOP = re.compile(r"^(\s*)for \w+ in (\d+):\s*$")
ONE_FRAME = re.compile(r"await (?:t\.frames\(1\)|t\.tree\.process_frame|get_tree\(\)\.process_frame)")


def measurements(lines):
    """Names that hold a wall-clock measurement, to a fixpoint. A measurement is a difference of clock readings, a timing the game
    measured itself (`area.build_ms`, `tracker.last_tick_usec`, `nav.bake_us`), or anything assigned, appended or iterated from one.
    Clock readings themselves (`var t0 := Time.get_ticks_usec()`, a deadline) are start marks, not measurements."""
    names = set()
    starts = set()
    changed = True
    while changed:
        changed = False
        for line in lines:
            code = line.split("#", 1)[0]
            loop = LOOP_VAR.match(code)
            if loop and loop.group(1) not in names and _mentions(loop.group(2), names):
                names.add(loop.group(1))
                changed = True
            for pattern in (ASSIGN, APPEND):
                m = pattern.search(code) if pattern is APPEND else pattern.match(code)
                if not m:
                    continue
                name, expr = m.group(1), m.group(2)
                if name in names:
                    continue
                if re.fullmatch(r"Time\.get_ticks_(?:usec|msec)\(\)(?:\s*\+.*)?", expr.strip()) or (name in starts and not TICKS.search(expr)):
                    starts.add(name)
                    continue
                difference = "-" in expr and (bool(TICKS.search(expr)) or _mentions(expr, starts))
                if difference or GAME_TIMING.search(expr) or _mentions(expr, names):
                    names.add(name)
                    changed = True
    return names


def _mentions(expr, names):
    return any(re.search(r"\b%s\b" % re.escape(n), expr) for n in names)


def check_calls(lines):
    """(line number, text of the whole call) of every check call; a call may span lines."""
    i = 0
    while i < len(lines):
        if CHECK.search(lines[i]):
            text = lines[i]
            depth = text.count("(") - text.count(")")
            j = i
            while depth > 0 and j + 1 < len(lines) and j - i < 6:
                j += 1
                text += "\n" + lines[j]
                depth += lines[j].count("(") - lines[j].count(")")
            yield i + 1, text
            i = j + 1
        else:
            i += 1


def outside_perf_ok(text, names):
    """The measurements of `names` (and timings the game measured itself) that an upper bound limits outside t.perf_ok(...)
    (`ms <= 0.4`, `limit >= ms`; a lower bound such as `build_ms > 0` only says that a timing was taken)."""
    stripped = re.sub(r"t\.perf_ok\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)", "PERF", text)
    stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', stripped)
    hit = []
    for name in names:
        n = re.escape(name)
        if re.search(r"\b%s\b(?:\.\w+|\[[^\]]*\])*\s*<=?(?!=)" % n, stripped) or re.search(r">=?\s*\b%s\b" % n, stripped):
            hit.append(name)
    for m in re.finditer(r"(\w+(?:\.\w+)*\.\w*_(?:ms|usec|us))\b\s*<=?(?!=)", stripped):
        hit.append(m.group(1))
    return sorted(set(hit))


def functions(lines):
    """(first line index, lines) of every top-level function (and the code before the first one)."""
    starts = [0] + [i for i, line in enumerate(lines) if re.match(r"^(?:static\s+)?func\s", line)]
    bounds = starts + [len(lines)]
    for k in range(len(starts)):
        yield bounds[k], lines[bounds[k]:bounds[k + 1]]


def raw_budgets(path, text):
    all_lines = text.split("\n")
    found = []
    for offset, lines in functions(all_lines):
        names = measurements(lines)
        for number, call in check_calls(lines):
            if EXEMPT in call:
                continue
            hit = outside_perf_ok(call, names)
            if hit:
                found.append("%s:%d [%s] %s" % (path, offset + number, ",".join(hit), lines[number - 1].strip()[:140]))
    return found


def frame_waits(path, text):
    lines = text.split("\n")
    found = []
    for i, line in enumerate(lines):
        m = FRAME_LOOP.match(line)
        if not m:
            continue
        indent = len(m.group(1).expandtabs(4))
        body = []
        j = i + 1
        while j < len(lines) and (lines[j].strip() == "" or len(lines[j].expandtabs(4)) - len(lines[j].expandtabs(4).lstrip()) > indent):
            body.append(lines[j])
            j += 1
        after = lines[j].strip() if j < len(lines) else ""
        if any(ONE_FRAME.search(b) for b in body) and after.startswith("t.fail("):
            found.append("%s:%d %s ... %s" % (path, i + 1, line.strip(), after[:80]))
    return found


def scan(root):
    files = sorted((root / "tests/sections").glob("*.gd")) + sorted(p for p in (root / "tests/lib").rglob("*.gd") if "selftest" not in p.parts)
    raw, frames = [], []
    for path in files:
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(root)
        raw += raw_budgets(rel, text)
        frames += frame_waits(rel, text)
    return files, raw, frames


BAD = {
    "raw": [
        "var t0 := Time.get_ticks_usec()\nfor i in 100: f()\nvar us := float(Time.get_ticks_usec() - t0) / 100.0\nt.check(\"idle\", us < 300.0, str(us))\n",
        "var costs: Array[float] = []\nfor i in 20:\n\tvar b := Time.get_ticks_usec()\n\tf()\n\tcosts.append((Time.get_ticks_usec() - b) / 1000.0)\ncosts.sort()\nvar p95 := costs[18]\nt.check(\"cost\", ok and p95 <= 25, \"\")\n",
        "var s := Time.get_ticks_msec()\nf()\nvar ms := Time.get_ticks_msec() - s\nt.check(\"both\", t.perf_ok(\"both\", ms, 5.0) and ms < 10, \"\")\n",
    ],
    "frames": [
        "func _finish(t) -> void:\n\tfor i in 800:\n\t\tawait t.frames(1)\n\t\tif done(): return\n\tt.fail(\"did not release\")\n",
    ],
}
GOOD = {
    "raw": [
        "var t0 := Time.get_ticks_usec()\nf()\nvar us := float(Time.get_ticks_usec() - t0)\nt.check(\"idle\", t.perf_ok(\"idle\", us, 300.0), \"%.1f us < 300\" % us)\n",
        "var took := Time.get_ticks_msec() - t0\nt.check(\"wait_ends_early\", took < 2500, \"\") # raw-time-ok: the wait must end before its 4 s timeout\n",
        "var deadline := Time.get_ticks_msec() + 60000\nt.check(\"x\", Time.get_ticks_msec() < deadline)\n",
    ],
    "frames": [
        "func _finish(t) -> void:\n\tif not await t.until_game(func(): return done(), 10.0):\n\t\tt.fail(\"did not release\")\n",
        "for i in 40:\n\tawait t.frames(1)\n\tif done(): break\nt.check(\"done\", done())\n",
    ],
}


def mutants():
    bad_raw = [s for s in BAD["raw"] if not raw_budgets("sample", s)]
    good_raw = [s for s in GOOD["raw"] if raw_budgets("sample", s)]
    bad_frames = [s for s in BAD["frames"] if not frame_waits("sample", s)]
    good_frames = [s for s in GOOD["frames"] if frame_waits("sample", s)]
    return bad_raw + bad_frames, good_raw + good_frames


def main(argv):
    verbose = "--verbose" in argv
    args = [a for a in argv if not a.startswith("--")]
    root = Path(args[0]).resolve() if args else ROOT
    files, raw, frames = scan(root)
    missed, false_hits = mutants()
    ok = True
    for rule, found, what in (("raw_wall_clock_budgets", raw, "raw wall-clock comparison(s) outside t.perf_ok()"), ("frame_count_waits", frames, "frame-count wait(s) ending in t.fail()")):
        if found:
            ok = False
            print("FAIL %s %d %s in %d files:" % (rule, len(found), what, len(files)))
            for row in found:
                print("  " + row)
        else:
            print("PASS %s (%d files)" % (rule, len(files)))
    if missed or false_hits:
        ok = False
        print("FAIL lint_detects_mutants missed %d bad sample(s), flagged %d good sample(s)" % (len(missed), len(false_hits)))
        if verbose:
            for s in missed + false_hits:
                print("  " + s.replace("\n", "\\n"))
    else:
        print("PASS lint_detects_mutants (%d bad samples flagged, %d good samples clean)" % (len(BAD["raw"]) + len(BAD["frames"]), len(GOOD["raw"]) + len(GOOD["frames"])))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
