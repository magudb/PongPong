kind = "dialogue"
id = "loop_neighbour"
function get_dialogue(ctx)
 return { lines = { { text_key = "DLG_LOOP_NEIGHBOUR_HELLO" } }, choices = { { text_key = "DLG_CHOICE_OPEN_SHOP", action = "shop", shop_id = "loop_shop" }, { text_key = "DLG_CHOICE_GOODBYE", action = "close" } } }
end
