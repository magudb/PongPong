extends RefCounted
## Trætoppen palette. Every value comes from the "Trætoppen Style Guide" v0.1
## (renderVals() in the .dc.html). Use:  const C = preload("res://scripts/ui/theme/tt_colors.gd")
## Deliberately NOT a class_name script: preload works even when the global class cache is stale.

# --- UI chrome (identical on every zone) ---
const INK := Color("#2b2340")           # outline, text
const PARCHMENT := Color("#f4e6c4")     # panel fill
const PARCHMENT_DARK := Color("#ecdcb4")# footers, empty slot, journal sidebar
const CHALK := Color("#fbf5e6")         # "Kridt": fields, cream buttons, selected rows
const GOLD := Color("#e3c372")          # "Fe-guld": focus / selected ring, pills
const GOLD_HOVER := Color("#ecd189")
const GOLD_DARK := Color("#a5781f")     # money numerals on parchment
const MOSS := Color("#6b9a3e")          # primary button, energy
const MOSS_HOVER := Color("#7aac49")
const MOSS_DARK := Color("#4d7a2a")     # "have enough" ingredient text
const HONEY := Color("#e8b04a")         # lantern oil meter (on parchment)
const BARK := Color("#7a4e2d")
const SKY := Color("#a9d3e0")
const LAVENDER := Color("#9b86d6")      # rare item ring
const LAVENDER_PALE := Color("#e2d8f4")
const LAVENDER_PALE2 := Color("#d3c6ee")
const ROSE := Color("#e58fa6")          # hearts, relationship
const ROSE_LIGHT := Color("#f2c3cf")    # half heart
const THORNBERRY := Color("#b3436b")    # damage / boss bar. NEVER red.
const RARE_TEXT := Color("#5d4fa3")

# --- text ---
const TEXT_MUTED := Color("#4c4058")
const TEXT_MONO := Color("#6a5a48")
const TEXT_FAINT := Color("#8d7c66")
const TEXT_DISABLED := Color("#a3957f")
const DISABLED_BG := Color("#e7d8b6")   # also meter track / vertical bar track
const DIVIDER := Color("#cdb98f")       # list-row border, quest divider
const INK_SOFT_30 := Color(0.169, 0.137, 0.251, 0.30)
const INK_SOFT_20 := Color(0.169, 0.137, 0.251, 0.20)
const INK_SOFT_15 := Color(0.169, 0.137, 0.251, 0.15)
const SHADOW := Color(0.169, 0.137, 0.251, 0.30)

# --- Mørkeskoven (forest HUD) ---
const NIGHT := Color("#1c2138")
const NIGHT_TRACK := Color("#2f3654")
const NIGHT_PANEL := Color(0.110, 0.129, 0.220, 0.85)
const SHADOW_MOSS := Color("#2f4a3f")
const GLOWSHROOM := Color("#6fd6c4")
const OWL_EYE := Color("#f2c14e")
const HEART_EMPTY := Color("#4a4560")

# --- zone swatches (for key art placeholders / tinting) ---
const ZONE_FARM_A := Color("#cde0a6")
const ZONE_FARM_B := Color("#bfd694")
const ZONE_TOWN_A := Color("#e2d8f4")
const ZONE_TOWN_B := Color("#d3c6ee")
const ZONE_FOREST_A := Color("#2f3654")
const ZONE_FOREST_B := Color("#262c48")
