"""Evaluate the current hand-owned Lua data with the repository's sandboxed serializer."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def snapshot():
    binary = os.environ.get("LUA") or shutil.which("lua5.4") or shutil.which("lua")
    if not binary:
        raise RuntimeError("Lua 5.4 is required (or set LUA to its executable)")
    files = sorted([*ROOT.glob("lua/items/*.lua"), *ROOT.glob("lua/config/*.lua"), ROOT/"lua/data/loot_tables.lua"])
    with tempfile.TemporaryDirectory(prefix="traetoppen-loot-model-") as directory:
        output = Path(directory)/"data.json"
        subprocess.run([binary,str(ROOT/"tools/features/validate/ser.lua"),str(output),*[str(p.relative_to(ROOT)) for p in files]],cwd=ROOT,check=True)
        records = json.loads(output.read_text())
    errors = [(row["file"],row["error"]) for row in records if row.get("error")]
    if errors:
        raise RuntimeError(f"Lua data failed to load: {errors}")
    return {row["file"]:row["globals"] for row in records}
