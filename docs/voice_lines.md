# Danish voice and placeholder sound pipeline

AudioManager is the only audio autoload. Its child AudioDirector reads `lua/config/audio.lua`; player Footsteps reads the same surface/variant data. There are thirteen plain players: eight SFX, two crossfading ambience, rain, music and voice. Every playback request, including missing files, enters a detached 256-entry cue log. Missing files stay silent. Danish voice stops on dialogue advance/close, world exit and locale switch; English never starts Danish speech. Volume settings share `user://settings.cfg [audio]` through load-modify-save and preserve other sections.

## Original recordings

All fourteen originals in `docs/audio/*.mp3` are archived byte-for-byte under `assets/audio/voice/_user_recordings_v0/` (excluded from runtime export). Its `mapping.json` records the sorted-file mapping and SHA-256 hashes. PLAN_2D R.5 documents the prior Danish ASR/duration investigation. Eleven current recordings are converted to mono 44.1 kHz Vorbis q4 without text or pitch changes; the three recordings naming retired characters remain archived. No fresh human listening review is claimed. The eleven canonical Danish texts are frozen in the generator and the existing dialogue copy.

`assets/audio/voice/RECORDED.txt` protects `voice/<npc_id>/<line_id>` paths. The generator never regenerates or overwrites listed files. To install a new actor recording, export mono OGG, use the exact voice key path, add it to RECORDED.txt and update the manifest with the generator. Keep peaks below -1 dBFS when mastering a new recording. Original user masters are never normalized or edited by this pipeline.

## Local Sara placeholders

```
python3 -B tools/voice/build_index.py --check
python3 -B tools/voice/generate_voice.py --install-recordings
python3 -B tools/voice/generate_voice.py --only postman_pip
python3 -B tools/voice/generate_voice.py --only-index --workers 4
python3 -B tools/voice/generate_voice.py --dry-run
python3 -B tools/voice/generate_voice.py --check
```

The generator scans all literal Lua dialogue `{text_key, voice_key}` pairs and resolves the effective Danish CSV text in loader order. Different text cannot share a voice path. CSV-selected social lines end in `_V`; the generated `_voiced_social.lua` makes those hooks visible to the same scanner and localization hash lint. Draft social copy is explicitly listed as missing until its CSV reaches `ai_reviewed` or `native_reviewed`. Run the generator after changing reviewed voiced copy. Human lines remain frozen. The initial manifest indexes 296 paths, with 11 human recordings, 175 local Sara lines and 110 draft social lines awaiting the copy pass.

`lua/config/voice_presets.lua` supplies eight archetypes: child 1.32/1.10, wanderer 1.22/1.16, fairy 1.18/1.08, shopkeeper 1.10/1.02, gardener 1.02/0.98, watcher 0.92/0.94, elder 0.84/0.82 and craftsman 0.74/0.88 (pitch/rate). Stable FNV-1a jitter adds at most ±4% pitch and ±3% rate per citizen. Other speakers use their NPC voice values. Pace is 0.88. Optional pronunciation entries use `respell = { ["display spelling"] = "spoken spelling" }`; displayed text is unchanged.

macOS `say -v Sara` writes temporary 22.05 kHz AIFF. ffmpeg applies `asetrate=22050*P,aresample=44100,atempo=1/P,atempo=0.88`, then encodes mono 22.05 kHz Vorbis q2. The compensating tempo filter preserves duration when pitch changes. Temporary files are removed. Text, parameters and final audio hashes drive idempotency. These are synthetic Danish placeholders, with no claim of actor performance or native listening approval. No network speech service is used.

## Cues and surfaces

Surface resolution uses the builder's callable first, then map ground: `d` wood, `c` stone, `=` rope, `p` dirt, `. , ; f` grass, then the area default. City decks use wood and rope bridges use rope; rooms use their floor material. Player footsteps occur every 0.333 s walking or 0.25 s running, use ±6% pitch variation and avoid consecutive variant repeats. Idle, blocked, flying, jumping, modal and teleport motion are silent. Surface lookup runs only when a step is due.

Gameplay cues: shop_bell (enter and exit), door_open_wood, door_locked_knock, coin_clink, heart_up, gift_sparkle, letter_rustle, page_turn, bath_splash, town_bell (outdoor city noon/evening once), festival_horn, closing_bell, bin_bell and stage_up. City movement, landmarks and equipment/appraisal use the mapped soft cues. Dungeon cues: pickup_soft, loot_rare, loot_unique, loot_legendary, chest_open, rune_activate, hulen_descend, telegraph_tick, enemy_notice, hit_soft, hurt_soft, bush_rustle, lantern_low, appraisal_reveal, gem_set and weapon_equip.

Ambience has farm/town day and night, shop interior, forest day/night, cave drips and a rain overlay. Raw clock hours 24 and 25 remain night. Caves/rooms suppress outdoor rain. Area changes crossfade for 1.5 seconds. Festival scores duck ambience by 6 dB and return to the area score afterward. Four dungeon acts, two boss scores and rune rest extend the farm/city/forest and four seasonal festival scores.

```
python3 -B tools/voice/sfx_synth.py
python3 -B tools/voice/ambience_synth.py
python3 -B tools/voice/music_synth.py
python3 -B tools/voice/test_audio_pipeline.py
```

The synth tools use deterministic pure-Python wave/math recipes and ffmpeg q2, mono 22.05 kHz. They produce 44 short cues (14 footsteps plus 14 town plus 16 dungeon), nine ambience loops and fourteen original sparse music placeholders. Recipe manifests retain hashes, PCM hashes and duration. `--check` verifies exports. Bump the recipe version when changing synthesis. One-second circular overlaps remove loop-boundary discontinuities. Replace a sound or tune by dropping a properly licensed OGG at the same filename and recording its provenance; these synth manifests deliberately detect changed files so the replacement can receive an explicit new record. The numeric waveform report covers silence, peaks, duration and seams; it is not an aesthetic listening review.
