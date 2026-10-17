kind = "quest"
id = "loop_mail"
objectives = { { id = "read", target = 1, on = "game_event", event = "post_read", description_key = "OBJ_LOOP_MAIL_READ" } }
rewards = { gold = 7 }
meta = { giver = "loop_neighbour", location = "ZONE_CITY", tag = "FIND", category = "daily", repeatable = false }
function on_offer(ctx) return { available = true, text_key = "QUEST_LOOP_MAIL_OFFER" } end
function is_available(ctx) return true end
