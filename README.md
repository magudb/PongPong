# PongPong — The Enchanted Forest

Et Stardew Valley-inspireret 2D-isometrisk farm- og eventyrspil i **Godot 4.7**, sat i en fortryllet skov blandt søde chibi-skovdyr og feer.

A Stardew Valley-inspired 2D isometric farming and adventure game in **Godot 4.7**, set in an enchanted forest among cute chibi forest animals and fairies.

See [Playing the game](docs/PLAYING.md) for current controls, clothing/loadout, homes, towns and the garden/forest journey. Validation and milestone evidence are tracked in [mechanics progress](docs/qa/mechanics/PROGRESS.md).

Windows and universal macOS builds are published to [GitHub Releases](https://github.com/magudb/PongPong/releases) when a `vX.Y.Z` tag passes CI. Installed production builds check for new releases; **Settings → Updates** downloads, verifies and installs an update after confirmation. See [release and signing setup](docs/RELEASING.txt).

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
- Godot 4.7+ (GL Compatibility renderer)
- Valgfrit: Lua GDExtension (f.eks. GodotLuaAPI) for fuld Lua-support
  — den indbyggede fallback-tolker dækker vores quest-format

---

## 📅 Roadmap

The game uses painted 2D characters and environments. Current implementation and verification are recorded in [MECHANICS_STATUS.json](docs/MECHANICS_STATUS.json), the [playing guide](docs/PLAYING.md), and the [fresh-save journey acceptance](docs/qa/journey/README.md).

- [x] Eight heroes, farming, animals, processing, sprinklers and greenhouse
- [x] Towns, scheduled citizens, shops, quests, friendships, relationships and festivals
- [x] Ten home tiers, furniture, wardrobe, inventory and save/load menus
- [x] Twelve dungeon floors, combat, bosses and the mother's story through its return-home ending
- [x] Area map on M and in the pause menu
- [ ] Human playtesting of onboarding, balance, all ten earned home tiers and social routes
- [ ] Native-speaker copy review and listening review; most voice lines remain synthetic placeholders
- [x] Windows/macOS release pipeline, exported-build checks and confirmed updates
- [ ] Low-end hardware, controller and long-session testing
- [ ] Optional collection screen and fishing

Children and multiplayer/co-op remain later scope. Some earlier design documents retain historical milestone deferrals; they are not a current list of missing mechanics.

---

## 📄 Licens / License

All rights reserved — proprietary game project.
