# PongPong Isometric 2D starter

**NEW:** The startup scene is now `res://scenes/isometric/demo_isometric_2d.tscn`, a standalone isometric 2D character test with all twelve sprite-sheet characters. For setup and integration, see [docs/ISOMETRIC_2D_README.md](docs/ISOMETRIC_2D_README.md). The original 3D game remains in `scenes/main/` and `scenes/player/`; its world and systems are **not yet converted to 2D**.

---

> Character integration update: see `docs/CHARACTER_INTEGRATION.md` for assets, controls,
> changes, test status and known limitations. Godot runtime checks are included but
> were not executed in the asset-generation environment.

# PongPong — The Enchanted Forest

Et Stardew Valley-inspireret 3D-farm- og eventyrspil i **Godot 4.7**, sat i en fortryllet skov blandt søde chibi-skovdyr og feer.

A Stardew Valley-inspired 3D farming and adventure game in **Godot 4.7**, set in an enchanted forest among cute chibi forest animals and fairies.

---

## 🌿 Koncept / Concept

| | |
|---|---|
| **Setting** | Enchanted forest with a fairy city and dark forest |
| **Farm** | Treetop farm won in the Fairy King's lottery |
| **Player** | Choose: Cute Forest Animal · Fairy · Hobbit |
| **Economy** | Grow crops, earn gold, buy upgrades |
| **Adventure** | Mine rare gems, metals in the dark forest |
| **Quests** | Help fairy citizens — fix roofs, find lost cats, deliver crops |
| **Extensibility** | Quests, dialogue & items written in **Lua** |
| **Language** | All copy & voices in **Danish** (English fallback) |

---

## 🗂 Projektstruktur / Project Structure

```
PongPong/
├── project.godot              # Godot 4.7 project config
├── icon.svg
├── assets/
│   ├── models/                # 3D models (chibi animals, fairies, hobbits)
│   ├── textures/
│   ├── audio/
│   │   ├── sfx/
│   │   ├── music/
│   │   └── voice/             # Danish voice lines
│   └── ui/
├── data/                      # JSON data exports
├── localization/
│   ├── da.csv                 # Danish (primary)
│   └── en.csv                 # English (fallback)
├── lua/                       # ★ Lua-driven content
│   ├── quests/                # Quest definitions
│   │   ├── intro_lottery.lua
│   │   ├── cookie_delivery.lua
│   │   ├── fix_roof.lua
│   │   ├── lost_cat.lua
│   │   └── dark_forest_mining.lua
│   ├── dialogue/              # NPC dialogue trees
│   │   ├── mayor_lyra.lua
│   │   ├── baker_maja.lua
│   │   ├── fairy_lily.lua
│   │   └── smith_thorin.lua
│   ├── items/                 # Item definitions
│   │   ├── crops.lua
│   │   ├── resources.lua
│   │   └── tools.lua
│   └── config/
│       └── game_balance.lua   # Tuning knobs
├── scenes/
│   ├── main/                  # main_menu.tscn, world.tscn
│   ├── player/                # player.tscn + skins/
│   ├── farm/
│   ├── city/
│   ├── forest/
│   └── ui/                    # character_select.tscn, HUD
└── scripts/
    ├── autoload/              # Global systems
    │   ├── event_bus.gd       # Signal hub
    │   ├── game_manager.gd    # Game state
    │   ├── lua_runtime.gd     # Lua bridge
    │   ├── quest_manager.gd   # Quest runtime
    │   ├── economy_manager.gd # Gold & inventory
    │   ├── save_manager.gd    # JSON save/load
    │   ├── time_manager.gd    # Clock & seasons
    │   ├── localization_manager.gd
    │   └── audio_manager.gd
    ├── player/
    ├── farm/
    ├── economy/
    ├── npc/
    ├── world/
    └── ui/
```

---

## 🎮 Gameplay-systemer / Game Systems

### Karaktervalg / Character Select
- **Sødt skovdyr** (Rabbit, Fox, Bear, Owl) — hurtig og elsket af dyrene
- **Fe** (Meadow, Stardust, Dusk) — magisk støv, kan svæve
- **Hobbit** (Pip, Moss, Bramble) — stærk, grønne fingre, elsker kager

### Trækronsgård / Treetop Farm
- 4×3 grid af dyrkningspletter
- Plov → Plant → Vand → Høst
- Afgrøder: majroe, gulerod, måneblomst, græskar
- Sæsonvækst og vejr-påvirkning

### Fe-Byen / Fairy City
- **Generel butik** — frø, værktøj, dagligvarer
- **Magibutikken** — fortryllede genstande, potions, magiske frø
- **Dyrehuset** — søde farmdyr (kyllinger, kaniner, killinger, lam, ræve, ugler)
- **Bageriet** — småkager, kager
- **Smedjen** — sværd, hakker

### Den Mørke Skov / Dark Forest
- Bryd jernmalm, guldmalm, sten, krystaller
- Sjældne fund: ametyst, smaragd, fe-støv
- Svampe-indsamling og heldige kløvere

### Quests (Lua-drevne)
| Quest | Giver | Type |
|-------|-------|------|
| Fe Kongens Lotteri | Lyra | Intro |
| Kager til Maja | Maja | Ærinde |
| Reparér taget | Maja | Hjælp |
| Den forsvundne kat | Lily | Hjælp |
| Mørk skov-ekspedition | Thorin | Eventyr |

---

## 🔧 Sådan udvider du quests / Extending Quests

Opret en ny `.lua`-fil i `lua/quests/`:

```lua
kind = "quest"
id = "my_new_quest"

objectives = {
  { id = "collect_flowers", target = 5, description = "Saml 5 blomster" },
}

rewards = {
  gold = 200,
  items = { fairy_dust = 1 },
}

meta = {
  giver = "mayor_lyra",
  category = "errand",
  repeatable = true,
}

function on_accept(context)
  api.set_flag("my_quest_active", true)
  return { ok = true }
end

function handle_event(event, payload)
  if event == "quest_completed" then
    api.add_gold(50)
  end
end

function is_available(context)
  return not api.has_flag("my_quest_active")
end
```

Genindlæs med `LuaRuntime.reload_scripts()` (eller genstart spillet).

### Lua API
| Funktion | Beskrivelse |
|----------|-------------|
| `api.add_gold(n)` | Tilføj guld |
| `api.add_item(id, n)` | Tilføj genstand |
| `api.remove_item(id, n)` | Fjern genstand |
| `api.has_item(id, n)` | Tjek genstand |
| `api.set_flag(k, v)` | Sæt verdens-flag |
| `api.get_flag(k)` | Hent flag |
| `api.notification(title, msg)` | Vis besked |
| `api.unlock_zone(id)` | Lås område op |
| `api.emit(event, payload)` | Send event |
| `api.log(msg)` | Skriv til log |
| `api.offer_quest(id)` | Tilbyd quest |
| `api.complete_quest(id)` | Afslut quest |

---

## 🇩🇰 Dansk lokalisering / Danish Localization

Alle strengene ligger i `localization/da.csv`. Format:

```
keys,da,en
ITEM_TURNIP,"Majroe","Turnip"
```

Voice-lines placeres i `assets/audio/voice/<npc>/<line>.ogg`.

---

## 🚀 Kom i gang / Getting Started

1. **Åbn projektet** i Godot 4.7+
2. **Kør** (F5) — main menu → Nyt spil → Vælg karakter
3. **Tilføj Lua-quests** i `lua/quests/`
4. **Tilføj dansk tekst** i `localization/da.csv`
5. **Tilføj 3D-modeller** i `scenes/player/skins/` og `assets/models/`

### Krav / Requirements
- Godot 4.7+ (Forward Plus renderer)
- Valgfrit: Lua GDExtension (f.eks. GodotLuaAPI) for fuld Lua-support
  — den indbyggede fallback-tolker dækker vores quest-format

---

## 📅 Roadmap

- [x] Kernearkitektur & autoloads
- [x] Karaktervalg (dyr / fe / hobbit)
- [x] Farm-system med afgrøder
- [x] Lua quest- & dialog-system
- [x] Økonomi & butikker
- [x] Mørk skov-mining
- [x] Dansk lokalisering
- [ ] 3D-modeller & animationer (chibi)
- [ ] Pathfinding & NPC-bevægelse
- [ ] Fuld voice-over
- [ ] Save-slot UI
- [ ] Sæson-events & festivaler
- [ ] Multiplayer (co-op)

---

## 📄 Licens / License

All rights reserved — proprietary game project.
