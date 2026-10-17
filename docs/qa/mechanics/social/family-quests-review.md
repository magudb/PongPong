# Natlys errands

Dyne’s three wool pay a blue knitted shirt and one heart. Gnist’s three glowing mushrooms and one night bloom pay 120 gold and three oil bottles. Their real quest objectives consume the exact materials on return and remain one-shot.

Silke’s weekly lost-property errand chooses among six named owners through the shared friendship/absence rule, excluding hero twins. The chosen owner, normal item, parcel receipt and translated objective key live in the existing quest runtime metadata. A full backpack defers the parcel until a later conversation with Silke; save/load preserves that state. Giving the correct item through the real gift flow completes it once, pays 60 gold and one heart with its owner, then enforces seven game days of cooldown.

The quest journal and reward grant share a small pure reward resolver, so the named heart shown is the heart paid. Optional runtime objective keys remain translation keys rather than saved display text. Eligibility queries use a static callable and survive disposal of a temporary helper. Zone restrictions retain their existing offer-only contract for scripted quest acceptance.

The authored content exporter reproduces all three quest files, six owner rows and 26 bilingual copy rows. The three citizens list their real quests. New copy remains draft; frozen recordings and all approved art are unchanged. Journal tags now have horizontal padding, keeping VENSKAB readable.

Acceptance:

- `family-quests-story-integration.json`: 308 checks across errands, generic quests, mother investigation and Secret Garden; no failures, skips or engine messages.
- `family-quests-integration.json`: 903 checks across seven sections, no failures or engine errors/warnings. One historical social-derived-data fixture skip remains for the final cleanup; fourteen expected negative-save/retired-NPC messages were explicitly allowed by their tests. The generic quest harness now checks dynamic friendship recipients and scans the new completer. Its two obsolete dungeon skips were replaced with actual generated floor-2/floor-7 anchors over two seeds.
- `family-quests-native.json`: four checks, no failures/skips/engine messages. The real conversation accepts Silke’s quest and opens the real journal. The final capture was opened and inspected: owner/item, heart recipient and 60-gold reward are readable, and the longer tag fits its plate.
