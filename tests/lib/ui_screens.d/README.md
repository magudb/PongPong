# tests/lib/ui_screens.d: registry rows of the packages that build screens

`UiAudit.screens()` (tests/lib/ui_audit.gd) reads `tests/lib/ui_screens.json` and then merges every `*.json` file of this folder,
in file-name order, so a package registers its screens without editing a file it does not own. One file per owning package:

| file | owner | rows |
|---|---|---|
| `social.json` | S-ui | people, gift, calendar, social_hud |
| `social_events.json` | S-events | event_overlay |
| `towns.json` | T-post-office | post |
| `controls.json` | Review fixes (input) | controls (Styring, nested in Settings) |

A file is `{"screens": [row, ...]}` with the row schema of `ui_screens.json` (see its `_doc` and the header of
`tests/sections/ui_audit.gd`: id, title, kind, scene, fixture, package, guide, focus, modal, esc_depth, compare, checks, options;
`status` is derived from the scene, nobody writes it). A key other than `screens` (a `_doc` note) is ignored.

* A screen id exists once, across `ui_screens.json` and all files of this folder. A second row with the same id, a row without an
  id and a file that does not parse are NOT merged and fail `ui_audit.screens_merge_dir_unique_ids` and `ui_audit.registry_valid`;
  `audit_screen(t, id)` of a duplicated id fails its own check `<id>.registry_unique_id`.
* Only `*.json` files count (this README and any other file type are ignored); the folder is not searched recursively.
* The rows are audited exactly like the rows of `ui_screens.json`: `await UiAudit.audit_screen(t, "<id>")` from the owner's own section.
