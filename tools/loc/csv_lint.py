#!/usr/bin/env python3
"""csv_lint.py - the LocalizationManager.lint() rules, offline (no Godot needed).

  python tools/loc/csv_lint.py [--dir localization] [--root .] [--strict] [--json] [--quiet]

Rules (identical to scripts/autoload/localization_manager.gd, PLAN 3.4 / R.4 / addendum 3.7):
  header        first row is `keys,da,en` (da and en columns are mandatory)
  malformed     key does not match ^[A-Z0-9_]+$, or the row has the wrong number of columns (row is skipped by the loader)
  duplicate     the same key twice in one file, or in two non-legacy files (da.csv is the legacy base and may be
                overridden silently; zz_final.csv is the override layer and is exempt from the cross-file rule)
  missing-text  a da or en cell is empty
  format        da and en take different % placeholders (a language switch must never raise a formatting error)
  keep-import   <file>.csv.import must exist and say importer="keep"
  ownership     a key is defined in a file other than its owner in tools/loc/key_owners.json
                (exact -> ITEM_<id>[_DESC|_HINT] of the item ids of the named Lua files -> longest prefix)
  voiced        zz_final.csv may not redefine the text_key of a dialogue line that has a voice_key (R.17)
  junk          generated *.translation files in the folder (warning)

Problems inside the legacy da.csv are "legacy" issues: tolerated until P26 prunes the file (exit 0), fatal with --strict.
Exit code: 0 clean, 1 errors (or legacy issues with --strict), 2 usage / unreadable folder.
"""
import argparse
import csv
import json
import os
import re
import sys

LEGACY_FILE = "da.csv"
FINAL_FILE = "zz_final.csv"
OWNERS_PATH = "tools/loc/key_owners.json"
KEY_RX = re.compile(r"^[A-Z0-9_]+$")
FORMAT_RX = re.compile(r"%[-+ #0]*(?:\*|\d+)?(?:\.(?:\*|\d+))?([sdifxXoecv])")


def issue(cat, sev, file, line, key, msg):
    return {"cat": cat, "sev": sev, "file": file, "line": line, "key": key, "msg": msg}


def format_issue(i):
    where = i["file"] + (":%d" % i["line"] if i["line"] > 0 else "")
    return "[%s] %s%s - %s" % (i["cat"], where, (" " + i["key"]) if i["key"] else "", i["msg"])


def format_signature(text):
    if "%" not in text:
        return ""
    return "".join(sorted(FORMAT_RX.findall(text.replace("%%", ""))))


def unescape_text(text):
    out, i = [], 0
    while i < len(text):
        ch = text[i]
        if ch == "\\" and i + 1 < len(text) and text[i + 1] in 'nt\\"':
            out.append({"n": "\n", "t": "\t"}.get(text[i + 1], text[i + 1]))
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def list_csv_files(folder):
    names = sorted(f for f in os.listdir(folder) if f.endswith(".csv"))
    if LEGACY_FILE in names:
        names.remove(LEGACY_FILE)
        names.insert(0, LEGACY_FILE)
    return names


def read_csv(path):
    """-> (header, [(line, cells)]) ; blank rows are dropped, line = 1-based first physical line of the record."""
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        rd = csv.reader(fh)
        header = next(rd, [])
        last = rd.line_num
        for cells in rd:
            start = last + 1
            last = rd.line_num
            if len(cells) <= 1 and (not cells or cells[0].strip() == ""):
                continue
            rows.append((start, cells))
    return header, rows


def check_keep_import(folder, fname, sev, issues):
    imp = os.path.join(folder, fname + ".import")
    if not os.path.isfile(imp):
        issues.append(issue("keep-import", sev, fname, 0, "", "%s.import is missing (every CSV ships a committed keep-import: tools/loc/new_csv.py)" % fname))
        return
    importer = ""
    section = ""
    for raw in open(imp, encoding="utf-8"):
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section == "remap" and line.startswith("importer="):
            importer = line.split("=", 1)[1].strip().strip('"')
    if importer != "keep":
        issues.append(issue("keep-import", sev, fname, 0, "",
                            '%s.import has importer="%s", it must be "keep" (otherwise --import writes .translation junk and exports drop the raw CSV)' % (fname, importer)))


# ---------------------------------------------------------------- Lua helpers (only what the lint needs)

def _strip_lua_noise(text):
    """Blank out comments and string contents so brace counting is safe (same length, newlines kept)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "-" and text.startswith("--", i):
            if text.startswith("[[", i + 2):
                end = text.find("]]", i + 4)
                end = n if end < 0 else end + 2
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            out.append("".join(ch if ch == "\n" else " " for ch in text[i:end]))
            i = end
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            out.append(c + "".join("\n" if ch == "\n" else "x" for ch in text[i + 1:j]) + c)
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def lua_table_ids(text, table_name):
    """Top-level entry names of `table_name = { id = {...}, ... }` at column 0 (the item ids of an items file)."""
    clean = _strip_lua_noise(text)
    m = re.search(r"(?m)^%s[ \t]*=[ \t]*\{" % re.escape(table_name), clean)
    if not m:
        return []
    ids, depth, i = [], 0, m.end() - 1
    n = len(clean)
    expect_entry = False
    while i < n:
        c = clean[i]
        if c == "{":
            depth += 1
            expect_entry = depth == 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        elif c == "," and depth == 1:
            expect_entry = True
        elif depth == 1 and expect_entry and (c.isalpha() or c == "_"):
            mm = re.match(r"([A-Za-z_][A-Za-z0-9_]*)[ \t\r\n]*=(?!=)", clean[i:])
            if mm:
                ids.append(mm.group(1))
                i += len(mm.group(1))
            expect_entry = False
            continue
        elif not c.isspace() and depth == 1:
            expect_entry = False
        i += 1
    return ids


def load_owners(root):
    path = os.path.join(root, OWNERS_PATH)
    if not os.path.isfile(path):
        return {}
    data = json.load(open(path, encoding="utf-8"))
    files = data.get("files", {})
    item_keys = {}
    for fname, spec in files.items():
        for lf in spec.get("item_files", []):
            lp = os.path.join(root, lf)
            if not os.path.isfile(lp):
                continue
            keys = item_keys.setdefault(fname, set())
            for item_id in lua_table_ids(open(lp, encoding="utf-8").read(), "items"):
                base = "ITEM_" + item_id.upper()
                keys.update((base, base + "_DESC", base + "_HINT"))
    return {"files": files, "item_keys": item_keys}


def owner_of(key, owners):
    files = owners.get("files", {})
    for fname, spec in files.items():
        if key in spec.get("exact", []):
            return fname
    for fname, keys in owners.get("item_keys", {}).items():
        if key in keys:
            return fname
    best, best_len = "", -1
    for fname, spec in files.items():
        for p in spec.get("prefix", []):
            if key.startswith(p) and len(p) > best_len:
                best, best_len = fname, len(p)
    return best


def voiced_keys(root):
    out = {}
    d = os.path.join(root, "lua", "dialogue")
    if not os.path.isdir(d):
        return out
    for f in sorted(os.listdir(d)):
        if not f.endswith(".lua"):
            continue
        src = open(os.path.join(d, f), encoding="utf-8").read()
        for block in re.findall(r"\{[^{}]*\}", src):
            if re.search(r'voice_key\s*=\s*"[^"]+"', block):
                m = re.search(r'text_key\s*=\s*"([A-Z0-9_]+)"', block)
                if m:
                    out[m.group(1)] = f
    return out


# ---------------------------------------------------------------- the lint

def lint(folder, root, with_extra=True):
    issues = []
    files = list_csv_files(folder)
    defs = []
    last_def = {}
    owners = load_owners(root) if with_extra else {}
    keys = set()
    for fname in files:
        legacy = fname == LEGACY_FILE
        is_final = fname == FINAL_FILE
        sev = "legacy" if legacy else "error"
        check_keep_import(folder, fname, sev, issues)
        try:
            header, rows = read_csv(os.path.join(folder, fname))
        except OSError:
            issues.append(issue("unreadable", sev, fname, 0, "", "the file cannot be opened"))
            continue
        cols = [h.strip().lower() for h in header[1:]]
        if not header or header[0].strip() != "keys" or "da" not in cols or "en" not in cols:
            issues.append(issue("header", sev, fname, 1, "", "the header must be `keys,da,en` (got `%s`)" % ",".join(header)))
        hcount = len(header)
        seen = {}
        for line, cells in rows:
            key = cells[0].strip() if cells else ""
            if key == "" or key.startswith(";") or key.startswith("#"):
                continue
            if not KEY_RX.match(key):
                issues.append(issue("malformed", sev, fname, line, key[:48], "key does not match ^[A-Z0-9_]+$ (row skipped)"))
                continue
            ccount = len(cells)
            while ccount > hcount and cells[ccount - 1].strip() == "":
                ccount -= 1
            if ccount != hcount:
                issues.append(issue("malformed", sev, fname, line, key, "expected %d columns, found %d (row skipped; quote texts that contain commas)" % (hcount, ccount)))
                continue
            if key in seen:
                issues.append(issue("duplicate", sev, fname, line, key, "defined twice in this file (first at line %d)" % seen[key]))
            elif not legacy and not is_final and key in last_def:
                of, ol = last_def[key]
                issues.append(issue("duplicate", "error", fname, line, key, "also defined in %s:%d (a key lives in exactly one non-legacy file)" % (of, ol)))
            seen[key] = line
            if not legacy:
                last_def[key] = (fname, line)
            text, missing = {}, []
            for ci, col in enumerate(cols):
                if col == "":
                    continue
                raw = cells[ci + 1]
                if raw.strip() == "":
                    missing.append(col)
                else:
                    text[col] = unescape_text(raw)
            if "da" in missing or "en" in missing:
                issues.append(issue("missing-text", sev, fname, line, key, "no text for: %s" % ", ".join(missing)))
            defs.append({"key": key, "file": fname, "line": line, "text": text})
            keys.add(key)
    for f in sorted(os.listdir(folder)):
        if f.endswith(".translation"):
            issues.append(issue("junk", "warning", f, 0, "", "generated .translation file (ignored by git; the runtime loader does not use it - delete it)"))
    if with_extra:
        voiced = voiced_keys(root) if FINAL_FILE in files else {}
        for d in defs:
            fname, key, text = d["file"], d["key"], d["text"]
            legacy = fname == LEGACY_FILE
            sev = "legacy" if legacy else "error"
            if "da" in text and "en" in text:
                sa, sb = format_signature(text["da"]), format_signature(text["en"])
                if sa != sb:
                    issues.append(issue("format", sev, fname, d["line"], key, "da takes [%s] but en takes [%s] (placeholder letters)" % (sa, sb)))
            if legacy:
                continue
            if fname == FINAL_FILE:
                if key in voiced:
                    issues.append(issue("voiced", "error", fname, d["line"], key, "voiced key (a dialogue line with a voice_key uses it): the copy pass may not change it (R.17)"))
                continue
            if not owners:
                continue
            own = owner_of(key, owners)
            if own and own != fname:
                issues.append(issue("ownership", "error", fname, d["line"], key, "owned by %s (tools/loc/key_owners.json), defined in %s" % (own, fname)))
        if owners:
            for fname in files:
                if fname not in (LEGACY_FILE, FINAL_FILE) and fname not in owners["files"]:
                    issues.append(issue("ownership", "warning", fname, 0, "", "%s is not listed in tools/loc/key_owners.json (add its key families)" % fname))
        elif files:
            issues.append(issue("ownership", "warning", "", 0, "", "%s was not found below %s: the ownership rule was not checked" % (OWNERS_PATH, root)))
    return {"files": files, "key_count": len(keys), "issues": issues}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Offline lint of localization/*.csv (same rules as LocalizationManager.lint()).")
    here = os.path.dirname(os.path.abspath(__file__))
    default_root = os.path.abspath(os.path.join(here, "..", ".."))
    ap.add_argument("--root", default=default_root, help="repository root (default: the checkout this script lives in)")
    ap.add_argument("--dir", default=None, help="folder with the CSVs (default: <root>/localization)")
    ap.add_argument("--strict", action="store_true", help="legacy (da.csv) issues are fatal too")
    ap.add_argument("--json", action="store_true", help="print the issues as JSON")
    ap.add_argument("--quiet", action="store_true", help="print only the summary line")
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    folder = os.path.abspath(a.dir) if a.dir else os.path.join(root, "localization")
    if not os.path.isdir(folder):
        print("csv_lint: not a folder: %s" % folder, file=sys.stderr)
        return 2
    rep = lint(folder, root)
    errors = [i for i in rep["issues"] if i["sev"] == "error"]
    legacy = [i for i in rep["issues"] if i["sev"] == "legacy"]
    warnings = [i for i in rep["issues"] if i["sev"] == "warning"]
    failed = bool(errors) or (a.strict and bool(legacy))
    if a.json:
        print(json.dumps({"files": rep["files"], "key_count": rep["key_count"], "issues": rep["issues"]}, ensure_ascii=False, indent=1))
    elif not a.quiet:
        for tag, lst in (("ERROR", errors), ("LEGACY" if not a.strict else "ERROR(legacy)", legacy), ("warning", warnings)):
            for i in lst:
                print("%s %s" % (tag, format_issue(i)))
    if not a.json:
        print("csv_lint %s: %d file(s), %d keys, %d error(s), %d legacy issue(s)%s, %d warning(s)" % (
            "FAIL" if failed else "PASS", len(rep["files"]), rep["key_count"], len(errors), len(legacy),
            " (fatal: --strict)" if a.strict and legacy else " (tolerated until P26)" if legacy else "", len(warnings)))
    return 1 if failed else 0


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
