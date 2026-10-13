#!/usr/bin/env python3
"""P01 boot gate: "the tree boots with ZERO engine errors and ZERO warnings", made measurable.

    python3 -I tests/tools/boot_check.py --project <CLONE> [--strict] [--fresh] [--frames 30]
    python3 -I tests/tools/boot_check.py --selftest

<CLONE> is a test copy of the repo (impl/tools/clone_run.sh or tools/dev/test_in_copy.sh), never the
real repo. The script runs `godot --headless --path <CLONE> --quit-after <frames>`, collects every
engine message block (ERROR / WARNING / SCRIPT ERROR / SCRIPT WARNING plus its indented `at:` and
backtrace lines) and sorts them into
  * KNOWN WAIVERS (below): a documented defect that belongs to ANOTHER package; reported, not fatal,
  * everything else: fatal.
Exit 0 = no unexpected message (waived ones are listed), 1 = unexpected message or a Godot exit code
other than 0, 2 = usage problem. A waiver that did not fire is reported as "no longer needed", so
the list shrinks as the owning packages land their fixes. --strict ignores the waivers: that is the
gate to run once the owners have landed (exit 1 while any waived message still appears).

--fresh additionally copies the project WITHOUT .godot to a scratch dir, runs `--import` twice (the
first run may print one-time font errors, so it is only reported; the second must be silent) and
boots that copy: the "fresh clone" gate of work order P01.

--selftest feeds synthetic engine output to the classifier (no Godot needed) and checks that a
waived message passes, any other message fails, --strict fails on the waived one and a clean boot
reports the waiver as unused.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")

# id, regex over the whole message block, owner, why
WAIVERS = [
    (
        "lua_runtime_reload_format",
        re.compile(r"String formatting error: not all arguments converted.*lua_runtime\.gd:42", re.S),
        "P10 (owns scripts/autoload/lua_runtime.gd; the line goes with the runtime loader of P03/P10)",
        "legacy lua_runtime.gd:42 does `tr(\"NOTIF_LUA_RELOADED_MSG\") % _scripts.size()`; with no "
        "locale/translations list (task 1, review R.2) tr() returns the bare key, so the format string "
        "has no placeholder and the engine logs one error per boot until LocalizationManager loads the "
        "CSVs at runtime (P03) or P10 guards the line",
    ),
]

START = re.compile(r"^(?:SCRIPT |USER )?(?:ERROR|WARNING)\b")


def blocks(text):
    """Engine message blocks: a start line plus the indented lines that follow it."""
    out = []
    cur = None
    for line in text.splitlines():
        if START.match(line):
            if cur is not None:
                out.append("\n".join(cur))
            cur = [line]
        elif cur is not None and line[:1] in (" ", "\t") and line.strip():
            cur.append(line)
        else:
            if cur is not None:
                out.append("\n".join(cur))
                cur = None
    if cur is not None:
        out.append("\n".join(cur))
    return out


def classify(text, strict=False):
    """Returns (unexpected blocks, waived [(waiver id, block)], unused waiver ids)."""
    unexpected, waived, hit = [], [], set()
    for b in blocks(text):
        wid = None
        if not strict:
            for (i, rx, _, _) in WAIVERS:
                if rx.search(b):
                    wid = i
                    break
        if wid is None:
            unexpected.append(b)
        else:
            waived.append((wid, b))
            hit.add(wid)
    unused = [i for (i, _, _, _) in WAIVERS if i not in hit]
    return unexpected, waived, unused


def run(project, extra, timeout=300):
    p = subprocess.run([GODOT, "--headless", "--path", project] + extra, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + "\n" + p.stderr


def report(title, rc, text, strict, boot=True):
    unexpected, waived, unused = classify(text, strict)
    print("%s: godot exit %d, %d unexpected message(s), %d waived" % (title, rc, len(unexpected), len(waived)))
    for b in unexpected:
        print("  UNEXPECTED " + b.replace("\n", "\n    "))
    for wid, b in waived:
        owner = [w for w in WAIVERS if w[0] == wid][0]
        print("  WAIVED %s (%s)\n    %s" % (wid, owner[2], b.splitlines()[0]))
    for wid in unused:
        if boot and not strict:
            print("  waiver %s did not fire: no longer needed, delete it from tests/tools/boot_check.py" % wid)
    return rc == 0 and not unexpected


def fresh_copy(project, dst):
    ignore = shutil.ignore_patterns(".godot", ".git", ".playwright-mcp", ".mimocode", "_stage", ".venv", "__pycache__")
    shutil.copytree(project, dst, symlinks=True, ignore=ignore)


def selftest():
    waived_msg = ("ERROR: String formatting error: not all arguments converted during string formatting.\n"
                  "   at: validated_evaluate (core/variant/variant_op.h:829)\n"
                  "   GDScript backtrace (most recent call first):\n"
                  "       [0] reload_scripts (res://scripts/autoload/lua_runtime.gd:42)\n"
                  "       [1] _ready (res://scripts/autoload/lua_runtime.gd:25)\n")
    other_err = "ERROR: Cannot open file 'res://x.png'.\n   at: open (core/io/file_access.cpp:1)\n"
    other_warn = "WARNING: something odd\n     at: foo (bar.cpp:3)\n"
    banner = "Godot Engine v4.7.2.stable.official\n\n"
    same_format_elsewhere = waived_msg.replace("lua_runtime.gd:42", "other.gd:7").replace("lua_runtime.gd:25", "other.gd:2")
    cases = []

    def case(name, ok):
        cases.append((name, ok))
        print("%s %s" % ("PASS" if ok else "FAIL", name))

    u, w, n = classify(banner)
    case("clean boot: nothing unexpected, the waiver is reported unused", not u and not w and n == ["lua_runtime_reload_format"])
    u, w, n = classify(banner + waived_msg)
    case("only the waived message: passes, listed as waived", not u and len(w) == 1 and not n)
    u, w, n = classify(banner + waived_msg + other_err)
    case("waived plus another error: the other error is fatal", len(u) == 1 and "Cannot open file" in u[0] and len(w) == 1)
    u, w, n = classify(banner + waived_msg + other_warn)
    case("waived plus a warning: the warning is fatal", len(u) == 1 and u[0].startswith("WARNING"))
    u, w, n = classify(banner + same_format_elsewhere)
    case("the same format error in ANOTHER script is not waived", len(u) == 1 and not w)
    u, w, n = classify(banner + waived_msg, strict=True)
    case("--strict: the waived message is fatal", len(u) == 1 and not w)
    u, w, n = classify(banner + "SCRIPT ERROR: Parse Error: x\n          at: GDScript::reload (res://a.gd:1)\n")
    case("SCRIPT ERROR blocks are collected", len(u) == 1 and "Parse Error" in u[0])
    u, w, n = classify(banner + "just a print about errors: 3 found\n")
    case("a plain print line is not an engine message", not u and not w)
    bad = [name for (name, ok) in cases if not ok]
    print("boot_check selftest: %d cases, %d failed" % (len(cases), len(bad)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", help="test copy of the repo (never the real repo)")
    ap.add_argument("--frames", type=int, default=30)
    ap.add_argument("--strict", action="store_true", help="do not tolerate the known waivers")
    ap.add_argument("--fresh", action="store_true", help="also run the fresh-copy gate: import twice, then boot")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not args.project or not os.path.isfile(os.path.join(args.project, "project.godot")):
        print("--project must point at a Godot project copy")
        return 2
    project = os.path.abspath(args.project)
    ok = True
    if args.fresh:
        scratch = tempfile.mkdtemp(prefix="p01_boot_fresh_")
        dst = os.path.join(scratch, "fresh")
        try:
            fresh_copy(project, dst)
            rc1, out1 = run(dst, ["--import"])
            u1, _, _ = classify(out1, args.strict)
            print("fresh copy, import 1: godot exit %d, %d message(s) (informational)" % (rc1, len(u1)))
            rc2, out2 = run(dst, ["--import"])
            ok = report("fresh copy, import 2 (must be silent)", rc2, out2, args.strict, boot=False) and ok
            rc3, out3 = run(dst, ["--quit-after", str(args.frames)])
            ok = report("fresh copy, boot", rc3, out3, args.strict) and ok
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
    rc, out = run(project, ["--quit-after", str(args.frames)])
    ok = report("boot", rc, out, args.strict) and ok
    print("P01 BOOT %s%s" % ("OK" if ok else "FAIL", " (strict)" if args.strict else " (known waivers tolerated)"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
