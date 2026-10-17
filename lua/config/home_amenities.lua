kind = "config"
config = {
  home_amenities = {
    royal_scene = {
      meta = { trigger = "automatic", npc = "fairy_king", once = true },
      steps = {
        { act = "fade", to = "black", seconds = 0.15 },
        { act = "camera", target = "fairy_king", zoom = 0.8, seconds = 0.4 },
        { act = "face", who = "fairy_king", dir = "S" },
        { act = "fade", to = "clear", seconds = 0.15 },
        { act = "say", who = "fairy_king", text_key = "HOME_AMENITIES_ROYAL_LINE_1" },
        { act = "say", who = "fairy_king", text_key = "HOME_AMENITIES_ROYAL_LINE_2" },
        { act = "say", who = "fairy_king", text_key = "HOME_AMENITIES_ROYAL_LINE_3" },
        { act = "sfx", id = "stage_up" },
        { act = "end" },
      },
    },
  },
}
