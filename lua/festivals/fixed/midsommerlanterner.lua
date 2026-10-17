-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  midsommerlanterner = {
    activities = {
      {
        id = "lantern_wish",
        kind = "wish",
        name_key = "FEST_MIDSOMMERLANTERNER_LANTERN_WISH",
        post = "fest_torvet_host",
      },
      {
        id = "bonfire_supper",
        kind = "feast",
        name_key = "FEST_MIDSOMMERLANTERNER_BONFIRE_SUPPER",
        post = "fest_torvet_table_1",
      },
      {
        id = "dance",
        kind = "dance",
        name_key = "FEST_MIDSOMMERLANTERNER_DANCE",
        post = "fest_torvet_host",
      },
    },
    meta = {
      area = "traetoppen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 14,
      desc_key = "FEST_MIDSOMMERLANTERNER_DESC",
      from = 18,
      host = "gardener_hoppe",
      name_key = "FEST_MIDSOMMERLANTERNER_NAME",
      season = "sommer",
      spot = "torvet",
      to = 23,
      stays_open = {},
      first = {
        "ghostfam_dyne",
        "ghostfam_gnist",
        "ghostfam_silke",
        "ghostfam_blund",
      },
      leave_early = {
        ghostfam_gnist = 1.25,
      },
    },
    rewards = {
      attend = {
        points = 20,
      },
      finale = {
        items = {
          honey_cake = 1,
        },
      },
    },
    scenes = {
      finale = "ev_midsommerlanterner_end",
      opening = "ev_midsommerlanterner_open",
    },
  },
}
