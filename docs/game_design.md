# Game Design Overview — PongPong

## Pillars

1. **Wonder and belonging** — The farm and towns offer warmth; the Dark Forest holds beautiful, unsettling fairy-tale mysteries, with a home to return to.
2. **Meaningful choice** — Animal / Fairy / Hobbit / Ghost each feel distinct while sharing the central search for our mother.
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
│  find clues │
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
| **Ghost** | At home in the night | Broader lantern light, reduced oil use |

---

## Progression

1. **Arrival**: Win the farm, meet the Fairy King and the neighbours, plant the first crops.
2. **First lead**: After the first-morning introduction, a letter in our mother's handwriting opens the investigation. Follow it when ready.
3. **Forest journey**: Take the Skovlift when its configured gate is open. Follow mother's traces through the changing forest, returning home between expeditions.
4. **Ongoing**: Farm upgrades, rare gems, festivals and friendships support the journey. Mining contracts remain side quests.

## Dark Forest story

Mørkeskoven's central story is a journey to discover what happened to our mother, inspired by *The Hazel Wood* by Melissa Albert. Family memories and unfinished fairy tales shape the investigation. We learn why she entered the wood, follow the work she left behind, and seek the truth about why she never returned.

The confirmed premise applies to all eight playable characters. The proposed chapters, forest rules and ghost-family continuity are in [the Dark Forest story addendum](design/DARK_FOREST_STORY_ADDENDUM.md). The mother's final fate remains a creative decision. This is the narrative direction for the upcoming adventure, not a claim that the new quest chain is already playable.

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
| Min Trækronsgård | Start | Farm and home to return to |
| Trætoppen | Arrival | Neighbours, Posthuset, Skovlift and family leads |
| Hyggebyen | Bridge from Trætoppen | Shops, repairs, food and town quests |
| Skovkanten | Skovlift's configured unlock | Forest hub, departure and return |
| Mørkeskoven | Depth progression | Main mother mystery, fairy-tale encounters, mining, rare loot and enemies |

---

## Content Pipeline (Lua)

1. Designer writes `lua/quests/my_quest.lua`
2. Adds Danish and English strings to the appropriate localization CSV and registers its key ownership
3. Reviews new copy; recorded lines follow the existing voice review and freeze workflow
4. `LuaRuntime.reload_scripts()` or restart
5. Quest appears in-game

Quests using existing objectives and dialogue APIs can be authored in Lua. Persistent story evidence, new encounter interactions and the mother-story journal need implementation before the proposed arc becomes playable.

---

## Art Direction

- **Style**: Hand-painted storybook chibi, matte gouache/watercolor, tactile grain and restrained magical light; [the approved style guide](art/style-guide.txt) governs the assets.
- **Palette**: Forest greens, warm golds, twilight purples
- **Characters**: Big heads, expressive eyes, rounded shapes
- **Environment**: Giant trees, glowing mushrooms, floating fireflies

---

## Audio Direction

- **Music**: Orchestral + Nordic folk (soft strings, flute, harp)
- **SFX**: Satisfying pops, sparkles, nature ambience
- **Voice**: Warm Danish narration & character voices
