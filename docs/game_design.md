# Game Design Overview — PongPong

## Pillars

1. **Cozy wonder** — Every corner of the forest should feel warm, magical, and inviting.
2. **Meaningful choice** — Animal / Fairy / Hobbit each feel distinct in play and story.
3. **Player-driven stories** — Lua quests let designers ship content without engine changes.
4. **Danish-first** — Language and voice reinforce the fairy-tale setting.

---

## Core Loop

```
┌─────────────┐
│  Wake up    │
│  on farm    │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐
│  Tend crops │────▶│  Harvest &   │
│  water/plant│     │  sell at city│
└──────┬──────┘     └──────┬───────┘
       │                   │
       ▼                   ▼
┌─────────────┐     ┌──────────────┐
│  Quests for │◀───▶│  Buy seeds,  │
│  citizens   │     │  tools, gear │
└──────┬──────┘     └──────────────┘
       │
       ▼
┌─────────────┐
│  Dark forest│
│  mine/explore│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Sleep, new │
│  day begins │
└─────────────┘
```

---

## Character Identity

| Type | Trait | Gameplay perk |
|------|-------|---------------|
| **Animal** | Loved by forest creatures | Faster movement, animals give gifts |
| **Fairy** | Magical dust & wings | Glide over gaps, magic crops grow faster |
| **Hobbit** | Sturdy & green-fingered | More stamina, higher crop yield |

---

## Progression

1. **Day 1–3**: Win farm, meet Lyra, plant first crops
2. **Week 1**: Help Maja & Lily, unlock city shops
3. **Week 2**: Thorin opens dark forest expedition
4. **Ongoing**: Farm upgrades, rare gems, festivals, friendship storylines

---

## Economy

| Source | Sink |
|--------|------|
| Crop sales | Seeds |
| Gem sales | Tool upgrades |
| Quest rewards | Farm expansions |
| Foraging | Food & gifts |

---

## Zones

| Zone | Unlock | Content |
|------|--------|---------|
| Trækronsgården | Start | Farm, home |
| Fe-Byen | Day 1 | Shops, NPCs, quests |
| Skovbrynet | Day 2 | Foraging, lost cat |
| Den Mørke Skov | Quest | Mining, rare loot, enemies |

---

## Content Pipeline (Lua)

1. Designer writes `lua/quests/my_quest.lua`
2. Adds Danish strings to `localization/da.csv`
3. (Optional) Records voice line
4. `LuaRuntime.reload_scripts()` or restart
5. Quest appears in-game

No GDScript changes required for new quests, dialogue, or items.

---

## Art Direction

- **Style**: Stylized chibi, soft colors, magical glow accents
- **Palette**: Forest greens, warm golds, twilight purples
- **Characters**: Big heads, expressive eyes, rounded shapes
- **Environment**: Giant trees, glowing mushrooms, floating fireflies

---

## Audio Direction

- **Music**: Orchestral + Nordic folk (soft strings, flute, harp)
- **SFX**: Satisfying pops, sparkles, nature ambience
- **Voice**: Warm Danish narration & character voices
