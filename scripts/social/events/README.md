# Social events

`SocialManager` attaches `SocialEventDirector` as a child. The director owns a four-entry queue; `SocialEventRunner` owns one transient scene. Friendship, seen stamps, annual attendance and owed item rewards remain in the existing social save. No autoload, input action or typed bus signal was added.

An event is a Lua `events` registry entry with `meta`, `steps` and `rewards`. `meta.trigger = "talk"` opts into the NPC choice; heart gates, `when` and `cooldown_days` determine availability. `once_per_year = true` compares the scene stamp with the current year. Other scenes are once per save. Festival opening and finale requests derive from the calendar and current area rather than requiring a remembered arrival edge.

The runner accepts `fade`, `stand`, `walk`, `face`, `camera`, `clip`, `emote`, `say`, `choice`, `give`, `points`, `flag`, `wait`, `time`, `sfx`, `end`. Adjacent `say` rows from one speaker share a dialogue session. A following `choice` supplies at most three choices; `reply_key`, `points` and `flag` are applied from the selected row. Skip defaults to option one. Missing actor APIs are counted in `skipped_directives`; text remains playable. Marks resolve through `NpcDirector.post_ground` and convert from area ground coordinates to world screen coordinates.

Effects stage until completion. Combined points are bounded at one heart per citizen per scene. Time advances at most 120 minutes and stops one minute before the configured day roll (01:59 on the current clock). Keepsakes cannot be given by a scene. Item rewards wait in the optional `social.owed` table when the relevant store is full. A successful ending clears the event modal, emits the completion event and autosaves.

`FestivalActivities` contains pure contest rules; `FestivalStage` owns the disposable interactions and annual transactions. Selection uses the existing item grid. The shared table has twelve contributions; six townsfolk arrive with food, later contributions follow the festival hour, and the player supplies the remaining dishes. The five fixed stall shops and real festival scenes are content data, separate from this runtime.

Heart content can name `meta.area` and `meta.after` (a saved earlier event ID). Ready scenes sort by their heart threshold, then ID. Prerequisite chains must resolve without cycles. A step may have a `when` condition using the same validated social grammar; the runner resolves these branches once at scene start, so playing normally and skipping apply the same branch. No recorded voice line is changed by the new unvoiced scenes.
