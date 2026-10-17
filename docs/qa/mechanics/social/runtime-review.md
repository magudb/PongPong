# Social event runtime

The existing “What’s on your mind?” dialogue action now reaches a real scene runner. Scenes queue until play resumes, hold the non-pausing `event` modal, freeze the clock, and block saving, sleeping and travel until their effects commit. Ordinary conversations keep their existing cancellation behavior.

The runner supports the documented sixteen directives, merges adjacent lines by speaker, uses the existing actor APIs, releases actors and camera control, and skips missing actor APIs without losing dialogue. Esc opens the existing confirmation with Continue selected. Skipping chooses the first remaining choice and commits the remaining effects once. Scene stamps, rewards, flags and point changes commit together; item notifications wait for that commit. Rewards that cannot fit remain in the version-one social save’s optional `owed` table and claim once when space opens. Older saves require no migration.

The area-owned festival stage exposes contests, shared-table donations, lantern wishes, feasts, dances and markets. It uses the towns’ actual navigation geometry and named posts, including the city’s separate level graph. It waits for town population to initialize after travel. Contests use deterministic annual scores and reject excessive or keepsake prizes before consuming the entry. The existing gift grid supplies a selection-only mode without gift limits or gift transactions. Important quest items and keepsakes remain protected.

`runtime-final.json` records 391 passing checks across live social data, the event runtime, activities and social UI (12 pixel checks require a window). `runtime-native.json` records 114 checks with no engine messages. Its dialogue, skip-confirmation and contest-picker captures were opened and visually inspected. The picker uses the approved book, item slots, focus rings and typography. The cinematic footer inherits the guide’s 11-pixel mono style with a documented cream text override for contrast on the ink bar. Social HUD chips hide during the scene and confirmation.

The scrolled gift-grid regression now selects the last occupied slot rather than a padding cell. The calendar native check accounts for the new fourth story tab. Neither change weakens the actual input or layout check.

The expanded dungeon catalog required small taste-data additions to keep the original 12% dislike limit: children appreciate berries and gentle forest supplies; Natteblik appreciates woodland walking staves and light-bearing wands. Loved-gift values, limits and weekly chat rewards are unchanged. Copy lint now recognizes the separately owned `SOC_EV_` system family and still rejects unknown citizen prefixes. Review counts were refreshed without promoting draft copy or altering frozen voice lines.

This package provides the runtime. The fixed festival content, heart scenes, relationship ladder, family events, live festival decoration and final full-game gate are tracked separately.
