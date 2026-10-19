# Lua API reference — Trætoppen

The game's data and small scripts live in `lua/**` and are run by `LuaRuntime` (`scripts/autoload/lua_runtime.gd`), a
pure-GDScript interpreter of a **subset** of Lua 5.4. This page is the authoring reference: what a file of each kind looks
like, which hooks run and what the `api` offers. The exact subset, the lint rules and the probe tooling are in
[`tools/lua/README.md`](../tools/lua/README.md); when the two disagree, the README and the runtime header win.

Every `lua` code block on this page is a complete file that lints clean (checked by `data.lua_api_doc_examples`).

## The subset in short

* Top level: `name = <literal>` and `name = { ... }` (data tables: literal values only), `function name(args) ... end`.
  Nothing else at the top level is read (`local`, a call, `return M` are lint findings).
* Inside a function: `local x = expr`, `x = expr`, `if ... then ... elseif ... then ... else ... end`, `do ... end`,
  `return expr`, `api.<name>(...)` calls. A `local` lives until the end of its block.
* Expressions: literals, names, `context.x`, `t[k]`, `and or not == ~= < <= > >= ..`, and table constructors, which are
  evaluated inside a function (`{ text_key = greet }` reads the local `greet`). A bare name that is not a local or a
  parameter reads the **world flag** of that name (`context.home_tier or home_tier or 1`).
* Not available: loops, arithmetic, `#`, the standard library (`string.`, `math.`, `print` ...), method calls, varargs,
  local or nested functions, field assignment (`t.x = v`), escapes in strings (texts belong in the CSV files).
* Lua truthiness: only `nil` and `false` are false; `0` and `""` are true.

Check a file with `godot --headless --path . -s res://tools/lua/lint.gd` (exit 0 = clean). CI also runs real Lua
(`luac5.4 -p`) over every file.

## File kinds

The `kind = "..."` header decides what a file is, in any directory.

| Kind | Top-level table | Read with |
|------|-----------------|-----------|
| `config` | `config = { ... }` (merged by top-level key; two files must not define the same key) | `LuaRuntime.get_config("a.b.c", default)` |
| `items` | `items = { <id> = { ... } }` | `get_item_def(id)`, `get_all_item_ids()` |
| `quest` | `objectives`, `rewards`, `meta` + hook functions | registered with `QuestManager` |
| `dialogue` | a `get_dialogue(context)` function | `get_dialogue(id, context)` |
| `recipes` | `recipes = { <id> = { ... } }` | `get_recipes(category)`, `get_recipe(id)` |
| `shops` | `shops = { <id> = { ... } }` | `get_shop(id)`, `get_shops()` |
| `registry` | `registry = "<name>"` + a table of that name | `get_registry(name)`, `get_registry_entry(name, id)` |

## Quest

```lua
kind = "quest"
id = "my_quest"

objectives = {
  { id = "collect_flowers", target = 5 },
}

rewards = {
  gold = 200,
  items = { turnip_seeds = 5 },
}

meta = {
  giver = "mayor_lyra",
  category = "errand",
  repeatable = false,
  cooldown_days = 0,
}

function is_available(context)
  return context.day >= 2 and not api.has_flag("my_quest_skipped")
end

function on_accept(payload)
  api.notification("LUANOTIF_MY_QUEST_ACCEPT_TITLE", "LUANOTIF_MY_QUEST_ACCEPT_TEXT")
end

function on_complete(payload)
  api.set_flag("my_quest_done", true)
end
```

Texts are keys: `QUEST_<ID>_TITLE`, `QUEST_<ID>_DESC`, `QUEST_<ID>_OFFER` (with a giver), `OBJ_<QUEST>_<OBJECTIVE>` or
`OBJ_<OBJECTIVE>`. How objectives are completed (`on`, `item`, `zone`, `consume` ...) is checked by QuestManager's binding
lint when the file is registered (`QuestManager.validate_definition`).

### Hooks

QuestManager calls a quest's hooks with `payload = { quest_id = "<id>" }`. For an event the runtime calls the first function
the file defines out of `<event>`, `on_<event>` and the alias below; only when none of them exists it calls
`handle_event(event, payload)`.

| Event | Alias | When |
|-------|-------|------|
| `quest_accepted` | `on_accept` | the player accepted the quest |
| `quest_completed` | `on_complete` | every objective is done |
| `quest_failed` | `on_fail` | the quest failed |
| `day_started` | `on_day_started` | a new game day, for every active quest |

`is_available(context)` decides whether the quest can be offered; `context` is `{ day, gold, home_tier }`. A quest without
it is always available. There is no hook for crop, item or zone events: objectives bind to those (`on = "..."`).

## Dialogue

```lua
kind = "dialogue"
id = "my_npc"

function get_dialogue(context)
  local greet = "DLG_MY_NPC_GREET"
  if context.hour < 10 then
    greet = "DLG_MY_NPC_MORNING"
  elseif context.season == "vinter" then
    greet = "DLG_MY_NPC_WINTER"
  end
  local bye = { id = "bye", text_key = "DLG_MY_NPC_BYE", action = "close" }
  return {
    lines = {
      { id = "greet", text_key = greet },
    },
    choices = {
      { id = "shop", text_key = "DLG_MY_NPC_SHOP", action = "open_shop", shop_id = "bakery" },
      bye,
    },
  }
end
```

`context` holds the world flags plus `hour day season weekday total_day weather race hero zone stamina_ratio`,
`quest_active_<id>` / `quest_done_<id>` / `quest_offer_<id>`, `friend_<npc>` (hearts), `shop_<id>` and the social and
opening-hours fields of the speaker (`scripts/world2d/npc_dialogue.gd`). The game fills in `speaker` and
`speaker_name_key` itself.

### Choice actions

| Action | Extra fields | Effect |
|--------|--------------|--------|
| `close` | — | ends the dialogue |
| `quest_accept`, `quest_offer` | `quest_id` | accepts the quest (only when it is offerable) |
| `open_shop` | `shop_id` | opens the shop |
| `open_journal` | — | opens the quest journal |
| `home_upgrade` | `tier` | opens the home builder |
| `show_info` | `info_key` | shows an info toast |
| `quest_update`, `give_item` | `quest_id`, `objective_id`, `needs`, `consume` | completes a manual objective |
| `emit_event` | `event`, `payload` | emits `EventBus.game_event` |
| `math_answer` | `answer`, `correct`, `result_flag`, `quest_id`, `objective_id` | a quiz answer |

Any other action is emitted as `game_event("dialogue_action", { npc, action, data })`.

## Items

```lua
kind = "items"

items = {
  my_item = {
    name_key = "ITEM_MY_ITEM",
    description_key = "ITEM_MY_ITEM_DESC",
    category = "material",
    rarity = "uncommon",
    max_stack = 99,
    buy_price = 50,
    sell_price = 25,
  },
}
```

`rarity` is on the ladder `normal uncommon rare unique legendary` (`common` is an alias of normal; anything else is the
lint finding `rarity`). Categories in use include `seed crop tool weapon material resource forage gem magic food
consumable product furniture clothing building_material placeable special`; furniture and clothing go to their own
stores, everything else to the backpack (`scripts/data/item_kinds.gd`).

## Config

```lua
kind = "config"

config = {
  my_feature = {
    enabled = true,
    speed = 5.5,
    rows = { { id = "a", weight = 2 }, { id = "b", weight = 1 } },
  },
}
```

From GDScript: `LuaRuntime.get_config("my_feature.speed", 5.0)`, or `GameData.cfg(...)` / `Svc.lua_config(...)` where an
autoload name cannot be used.

## Recipes and shops

```lua
kind = "recipes"

recipes = {
  my_bouquet = {
    name_key = "RECIPE_MY_BOUQUET",
    category = "craft",
    ingredients = { wild_flower = 3, honey = 1 },
    output = { item = "my_bouquet", amount = 1 },
  },
}
```

```lua
kind = "shops"

shops = {
  my_shop = {
    name_key = "SHOP_MY_SHOP",
    keeper = "baker_maja",
    greeting_key = "SHOP_MY_SHOP_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    stock = {
      flour = { stock = 20, restock = 20 },
    },
  },
}
```

The shop fields (tabs, rotation, price curve, opening days, what it buys) are explained in `lua/shops/seed_shop.lua`; the
registry kind (routines, buildings, events, festivals) in `tools/lua/README.md`.

## API functions

Inside a function, `api.<name>(...)` (or the bare name) calls the game. Anything else is the lint finding
`unknown_function` and answers nil.

| Function | Answer / effect |
|----------|-----------------|
| `api.add_gold(n)` | adds gold |
| `api.add_item(id, n)` | adds `n` (default 1) of an item |
| `api.remove_item(id, n)` | removes items; true when it could |
| `api.has_item(id, n)` | true when the player owns at least `n` |
| `api.get_gold()` | the player's gold |
| `api.set_flag(key, value)` | sets a world flag (`value` defaults to true) |
| `api.get_flag(key)` | the flag's value, nil when unset |
| `api.has_flag(key)` | true when the flag is set to a true value |
| `api.notification(title, message)` | a toast; both go through `tr()` (keys) |
| `api.unlock_zone(id)` | unlocks a zone |
| `api.emit(event, payload)` | `EventBus.lua_event(event, payload)` (`quest_offer` `quest_accept` `quest_update` `quest_complete` `quest_fail` drive QuestManager) |
| `api.log(message)` | prints `[Lua] message` |
| `api.offer_quest(id)` | offers a quest |
| `api.complete_quest(id)` | completes a quest |
| `api.get_hearts(npc)` | whole hearts of a citizen |
| `api.add_hearts(npc, n)` | adds hearts |
| `api.is_birthday(npc)` | true on the citizen's birthday |
| `api.festival()` | today's active festival id, `""` when none (a TRUE string: compare it, `api.festival() ~= ""`) |

## Localization

Texts are never written in Lua: a file names keys, and the texts live in `localization/*.csv` (`keys,da,en`, Danish first,
English as the fallback; see `tools/loc/README.md`). Code resolves them with `LocalizationManager.t(key)` or `tr(key)`.

## Hot reload and messages

In a debug build F9 re-reads every file (`LuaRuntime.reload_scripts()`), toasts the script count and the number of lint
findings, and emits `EventBus.lua_reloaded` so the systems that copied Lua data refresh it. At load a debug build lints every
file into `LuaRuntime.lint_report`; a release build keeps only the data-level checks. A mistake that only shows when a
function runs (an unknown api function, a skipped statement, a comparison of unlike types) is an engine warning that names
the file, line and function, once per script, and is kept in `LuaRuntime.runtime_report`.
