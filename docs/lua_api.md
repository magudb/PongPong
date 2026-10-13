# Lua API Reference — PongPong

Quests, dialogue, items, and balance are authored in Lua and hot-reloadable.

## File layout

| Path | Kind | Purpose |
|------|------|---------|
| `lua/quests/*.lua` | `quest` | Quest definitions & logic |
| `lua/dialogue/*.lua` | `dialogue` | NPC dialogue trees |
| `lua/items/*.lua` | `items` | Item catalogs |
| `lua/config/*.lua` | `config` | Balance & tuning |

---

## Quest module

```lua
kind = "quest"
id = "my_quest"              -- unique id, used in localization keys

objectives = {
  { id = "obj_id", target = 5, description = "Danish text" },
}

rewards = {
  gold = 200,
  items = { turnip_seeds = 5, fairy_dust = 1 },
}

meta = {
  giver = "npc_id",
  category = "errand|help|adventure|intro",
  repeatable = false,
  cooldown_days = 0,
  requires_zone = "dark_forest",
}
```

### Hooks (all optional)

| Function | When | Args |
|----------|------|------|
| `on_offer(context)` | Quest becomes available | `context` table |
| `on_accept(context)` | Player accepts | `context` table |
| `handle_event(event, payload)` | Any game event | `event` string, `payload` table |
| `on_day_started(context)` | Each in-game day | `context` table |
| `is_available(context)` | Availability check | returns `true`/`false` |

### Common events for `handle_event`

- `"quest_accepted"` / `"quest_completed"` / `"quest_failed"`
- `"crop_harvested"` — `payload = { plot_id, crop_id, amount }`
- `"item_collected"` — `payload = { item_id, amount }`
- `"zone_entered"` — `payload = { zone_id }`
- `"day_started"` — `payload = { day, season }`

---

## Dialogue module

```lua
kind = "dialogue"
id = "mayor_lyra"

function get_dialogue(context)
  return {
    speaker = "mayor_lyra",
    speaker_name_key = "NPC_MAYOR_LYRA",
    lines = {
      { id = "greet", text_key = "DIALOGUE_LYRA_GREET", voice_key = "voice/lyra/greet" },
    },
    choices = {
      { id = "accept", text_key = "DIALOGUE_CHOICE_ACCEPT", action = "quest_accept", quest_id = "my_quest" },
      { id = "shop",   text_key = "DIALOGUE_CHOICE_SHOP",   action = "open_shop",     shop_id = "bakery" },
      { id = "bye",    text_key = "DIALOGUE_CHOICE_GOODBYE", action = "close" },
    },
  }
end
```

### Choice actions

| Action | Extra fields | Effect |
|--------|-------------|--------|
| `quest_accept` | `quest_id` | Accept quest |
| `quest_offer` | `quest_id` | Offer quest |
| `open_shop` | `shop_id` | Open shop UI |
| `open_journal` | — | Open quest journal |
| `show_info` | `info_key` | Show info popup |
| `close` | — | End dialogue |

---

## Items module

```lua
kind = "items"

items = {
  my_item = {
    name_key = "ITEM_MY_ITEM",
    category = "seed|crop|tool|weapon|resource|forage|gem|magic|food|special",
    buy_price = 50,
    sell_price = 25,
    description_key = "ITEM_MY_ITEM_DESC",
    -- optional fields:
    crop_id = "turnip",        -- for seeds
    tool_type = "hoe",
    power = 1,
    damage = 5,
    rarity = "common|uncommon|rare|epic",
  },
}
```

---

## Config module

```lua
kind = "config"

config = {
  player = { walk_speed = 5.5, max_health = 100 },
  crops = {
    turnip = { stages = 4, days_per_stage = 1, sell_price = 45 },
  },
}
```

Access from GDScript: `LuaRuntime.get_config("crops.turnip.sell_price", 45)`

---

## API functions (inside Lua)

| Function | Description |
|----------|-------------|
| `api.add_gold(n)` | Add gold |
| `api.add_item(id, n)` | Add item to inventory |
| `api.remove_item(id, n)` | Remove item |
| `api.has_item(id, n)` | Check inventory (returns bool) |
| `api.set_flag(key, value)` | Set world flag |
| `api.get_flag(key)` | Get world flag |
| `api.notification(title, msg)` | Show notification |
| `api.unlock_zone(id)` | Unlock a zone |
| `api.emit(event, payload)` | Fire a global event |
| `api.log(msg)` | Print to output |
| `api.offer_quest(id)` | Make quest available |
| `api.complete_quest(id)` | Force-complete quest |

---

## Localization keys

Quest/dialogue text uses keys resolved in `localization/da.csv`:

| Pattern | Example |
|---------|---------|
| `QUEST_<ID>_TITLE` | `QUEST_MY_QUEST_TITLE` |
| `DIALOGUE_<SPEAKER>_<LINE>` | `DIALOGUE_LYRA_GREET` |
| `ITEM_<ID>` | `ITEM_MY_ITEM` |
| `OBJ_<OBJECTIVE_ID>` | `OBJ_COLLECT_FLOWERS` |
| `NPC_<ID>` | `NPC_MAYOR_LYRA` |

Voice files: `assets/audio/voice/<speaker>/<line>.ogg`

---

## Hot reload

During development:

```gdscript
LuaRuntime.reload_scripts()
```

Or restart the game. All `lua/**` files are rescanned on boot.
