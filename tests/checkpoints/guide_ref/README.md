# tests/checkpoints/guide_ref - the style guide at 1280x720 (package P07)

`pw1x_<screen>.png` (title, select, hud, shop, quest, inventory, forest) are the seven screen boxes of `docs/Trætoppen Style Guide Review/Trætoppen Style Guide.dc.html`
rendered by Playwright (Chromium, device scale 1, the Google Fonts the guide names), 1280x720 each including the guide's 2 px ink frame. They are committed so that
`tests/checkpoints/compare_guide.py` needs no browser at test time. The folder carries a `.gdignore`: Godot never imports these PNGs, python reads them directly.

The first set (the UI spike's `spike_ui_shots/pw1x_*.png`) was lost when the session scratchpad was wiped; this set was regenerated from the same HTML on 2026-10-13.
Regenerate (any screen box can be done the same way): serve the guide folder (`python3 -m http.server`), open the page at a 1500x900 viewport, pin one
`[data-screen-label=...]` element to `position:fixed; left:0; top:0` so it sits on whole pixels, and take a `page.screenshot({clip: {x:0, y:0, width:1280, height:720}})`.

Use: `python tests/checkpoints/compare_guide.py hud=OUT/hud.png title=OUT/title.png` (see its header: `--ref`, `--no-frame-crop`, `--region`, `--max`, `--target`).

## This set is the baseline (pinned)
The spike's originals were lost, so this regenerated set is the BASELINE every diff target (F7, F8, P27) is measured against; compare_guide.py on the
spike's own re-rendered screens gives the same numbers as the spike report for title / select / forest (within 0.15) and 0.4-2.2 less than the quoted
hud / quest / shop / inventory (7.57 vs 8.2, 10.87 vs 11.3, 16.60 vs 17.5, 19.75 vs 21.9), so a target set on a number is only comparable against THIS set.
`SHA256SUMS` pins the seven files and `tests/sections/ui_foundation.gd` (`ui_foundation.guide_ref_pinned`) fails when one changes.
The fonts at render time were the Google-hosted Caprasimo, Alegreya Sans and IBM Plex Mono that the guide's own stylesheet links (Google serves the current
revision; no revision number is recorded), so a later font revision is the one thing that would move a regeneration. To replace a reference ON PURPOSE:
regenerate it (above), then `cd tests/checkpoints/guide_ref && shasum -a 256 pw1x_*.png > SHA256SUMS` in the same change and tell the owners of the targets.
Lead decision pending: accept this set as the baseline (default) or recover the spike's original renders.
