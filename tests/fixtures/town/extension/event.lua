kind = "registry"
registry = "events"
events = { loop_heart_event = {
 meta = { npc = "loop_neighbour", hearts = 1, when = "hour:6-26", title_key = "EV_LOOP_TITLE" },
 steps = { { act = "say", who = "loop_neighbour", text_key = "DLG_LOOP_NEIGHBOUR_HELLO" } }, rewards = { points = 0 },
} }
