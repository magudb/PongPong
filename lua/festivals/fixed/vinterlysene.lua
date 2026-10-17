-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  vinterlysene = {
    activities = {
      {
        id = "light_procession",
        kind = "dance",
        name_key = "FEST_VINTERLYSENE_LIGHT_PROCESSION",
        post = "fest_torvet_host",
      },
      {
        id = "lantern_wish",
        kind = "wish",
        name_key = "FEST_VINTERLYSENE_LANTERN_WISH",
        post = "fest_torvet_host",
      },
      {
        id = "warm_drinks",
        kind = "feast",
        name_key = "FEST_VINTERLYSENE_WARM_DRINKS",
        post = "fest_torvet_table_1",
      },
    },
    meta = {
      area = "traetoppen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 7,
      desc_key = "FEST_VINTERLYSENE_DESC",
      from = 16,
      host = "fairy_lily",
      name_key = "FEST_VINTERLYSENE_NAME",
      season = "vinter",
      spot = "torvet",
      to = 21,
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
      finale = "ev_vinterlysene_end",
      opening = "ev_vinterlysene_open",
    },
  },
}
