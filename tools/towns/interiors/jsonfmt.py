"""A readable, deterministic JSON writer for the generated data files of the interiors: dictionaries are indented, lists and short objects that fit a line stay on one line."""
from __future__ import annotations

import json
from typing import Any

WIDTH = 170


def _flat(o: Any) -> str:
    return json.dumps(o, ensure_ascii=False, separators=(", ", ": "))


def dumps(o: Any, level: int = 0) -> str:
    pad = " " * level
    pad1 = " " * (level + 1)
    if isinstance(o, dict):
        if not o:
            return "{}"
        flat = _flat(o)
        if level > 0 and len(flat) + len(pad) <= WIDTH:
            return flat
        parts = [f"{pad1}{json.dumps(k, ensure_ascii=False)}: {dumps(v, level + 1)}" for k, v in o.items()]
        return "{\n" + ",\n".join(parts) + "\n" + pad + "}"
    if isinstance(o, list):
        if not o:
            return "[]"
        flat = _flat(o)
        if len(flat) + len(pad) <= WIDTH:
            return flat
        parts = [f"{pad1}{dumps(x, level + 1)}" for x in o]
        return "[\n" + ",\n".join(parts) + "\n" + pad + "]"
    return json.dumps(o, ensure_ascii=False)


def text(o: Any) -> str:
    return dumps(o) + "\n"
