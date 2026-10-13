# Localization tools (P03-loc-core)

The game loads `localization/*.csv` at run time (`scripts/autoload/localization_manager.gd`): no import step, no `.translation` files
(the CSV importer must never see a CSV: every `localization/<name>.csv` ships a committed `<name>.csv.import` with `importer="keep"`).

| Tool | What it does |
|---|---|
| `python tools/loc/csv_lint.py [--strict] [--json] [--root .]` | the rules of `LocalizationManager.lint()` offline (header, malformed rows, duplicates, missing da/en text, `%` placeholders, keep-imports, key ownership, voiced keys). Exit 1 on errors; problems inside the legacy `da.csv` are tolerated until P26 prunes it (`--strict` makes them fatal). |
| `godot --headless --path . -s res://tests/loc_check.gd [-- --strict]` | the same lint + key coverage: every key named in `scripts/`, `scenes/`, `lua/`, `data/maps/` (literals and the dynamic families) must exist in da AND en. Lenient mode exits 0 unless the non-legacy CSVs break a rule; `--strict` (P26's gate) exits 1 on anything. `--dump=FILE` writes the reference index, `--root=PATH` scans another project root. |
| `python tools/loc/new_csv.py NAME [--row "KEY=da text\|en text"]` | creates `localization/NAME.csv` and its keep-import. |
| `python tools/loc/prune_legacy.py --godot [--apply]` | P26 only: lists / removes the rows of `da.csv` that are overridden by another CSV, malformed, duplicated or referenced nowhere (the reference index comes from `loc_check.gd --dump`). |
| `tools/loc/key_owners.json` | key-level ownership table (PLAN R.4 for the base files, addendum 3.7 for the feature files). |

## Load order and overrides
`da.csv` (legacy base) first, then every other `*.csv` alphabetically (`zz_final.csv` therefore last). A later file overrides an earlier key per locale.
Overriding a `da.csv` key is allowed and silent; the same key twice in one non-legacy file, or in two non-legacy files, is a lint error.
`zz_final.csv` (P26, copy pass) is the only file that may redefine keys of other files, but never a voiced key (the `text_key` of a dialogue line that has a `voice_key`).
Rows whose first cell starts with `;` or `#` are comments (do not put a double quote into a comment line: the CSV reader would start a quoted field).
A key must match `^[A-Z0-9_]+$`; texts use `\n` for a line break and `%s` / `%d` placeholders (da and en must take the same ones).

## Key ownership
`key_owners.json` maps every CSV to the key families it owns: an `exact` key wins; else `ITEM_<id>[_DESC|_HINT]` of the item ids found in the Lua files named in `item_files`;
else the LONGEST matching `prefix`. A key that no file claims is unconstrained (it only has to be unique). To give a new CSV a family, ask P03 to extend the table
(other packages never edit it); `new_csv.py` deliberately does not touch it.

## The scene rule
Scenes hold KEYS as `text` (`Label.text = "MENU_NEW_GAME"` translates itself and follows `LocalizationManager.set_locale`). Text built in code uses
`LocalizationManager.t("KEY", [args])`; it never applies `%` to an untranslated key. A harness check for "raw keys on screen" must look at what the node DISPLAYS
(`label.atr(label.text)`), not at `label.text`.
