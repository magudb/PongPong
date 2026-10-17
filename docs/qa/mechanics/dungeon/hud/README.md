# Forest HUD and gathering checkpoint

The dedicated action HUD keeps health, oil and refill counts, the actual equipped/action item, boss phases, the floor title, four combat abilities, whispers and pack/assist status readable. Its minimap caches terrain and reveals a fourteen-cell radius for each visit; maps reveal the entire floor. Pickup feed rows follow ownership, coalesce, expire and retain category-independent rarity rings and pips.

Unique and legendary presentations run after ownership commits. Appraisal results remain visible above the appraisal modal in towns. Skip preserves the item, releases only this reveal's stun and restores temporary music ducking. Reduced-flash mode uses a static card without dimming or particles. Cue routing tolerates absent sound files.

The native gathering/reveal run passed 99 checks without engine messages. The HUD run passed 23, including the nine-heart layout, picker checklist and update timing. The sampled cost was 0.0040 ms for the four cooldowns and 0.0867 ms per minimap update, or 0.0185 ms/frame at 60 Hz with the minimap at 10 Hz. This measures warmed callbacks, not whole-frame renderer cost.

The isolated comparison reproduces the style guide's CSS backdrop, with no game art substituted into that fixture. `guide-comparison.json` records mean RGB difference 10.174, below the 15 target. The separate native forest screenshots exercise the painted world. These images were opened and reviewed.

Real input tests cover the action-area tool-use routing, stamina, selected-tool E interaction, gathering cancellation, delayed pickup quest progress, static respawn and stable dungeon consumption. The old farm-HUD toast failure now passes with the forest HUD present.

New dungeon weapon/gem artwork remains a separate pending package. The unchanged held-equipment catalog test correctly reports the 22 new weapons without painted turnarounds; that test has not been weakened or skipped. Sound cue names are connected, while final audio content and forest dressing remain pending.
