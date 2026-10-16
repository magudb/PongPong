-- quests/forste_dage.lua (package N04, a carve-out of P13's lua/quests/**): the farm tutorial as an ordinary quest.
-- Auto-accepted by the first morning (TutorialRunner) like intro_lottery. The hints only run while it is active.
kind = "quest"
id = "forste_dage"

objectives = {
  { id = "till", target = 3, on = "game_event", event = "plot_tilled", description_key = "OBJ_FORSTE_DAGE_TILL" },
  { id = "plant", target = 3, on = "crop_planted", description_key = "OBJ_FORSTE_DAGE_PLANT" },
  { id = "water", target = 3, on = "crop_watered", description_key = "OBJ_FORSTE_DAGE_WATER" },
  { id = "mail", target = 1, on = "game_event", event = "post_read", description_key = "OBJ_FORSTE_DAGE_MAIL" },
  { id = "harvest", target = 1, on = "crop_harvested", description_key = "OBJ_FORSTE_DAGE_HARVEST" },
}

rewards = {
  gold = 150,
  items = {
    carrot_seeds = 10,
    fertilizer = 3,
  },
  friendship = {
    postman_pip = 1,
  },
}

meta = {
  giver = "postman_pip",
  tag = "LÆR",
  location = "ZONE_FARM",
  category = "intro",
  repeatable = false,
}
