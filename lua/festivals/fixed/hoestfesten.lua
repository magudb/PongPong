-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  hoestfesten = {
    activities = {
      {
        id = "pumpkin_contest",
        kind = "contest",
        name_key = "FEST_HOESTFESTEN_PUMPKIN_CONTEST",
        post = "fest_torvet_judge",
        select = "category:crop",
      },
      {
        id = "harvest_feast",
        kind = "feast",
        name_key = "FEST_HOESTFESTEN_HARVEST_FEAST",
        post = "fest_torvet_table_1",
      },
      {
        id = "harvest_market",
        kind = "market",
        name_key = "FEST_HOESTFESTEN_HARVEST_MARKET",
        post = "fest_torvet_stall_1",
        shop = "fest_harvest_market",
      },
    },
    meta = {
      area = "traetoppen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 14,
      desc_key = "FEST_HOESTFESTEN_DESC",
      from = 12,
      host = "mayor_lyra",
      name_key = "FEST_HOESTFESTEN_NAME",
      season = "efteraar",
      spot = "torvet",
      stays_open = {
        "bakery",
      },
      to = 20,
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
      contest = {
        first = {
          items = {
            pumpkin_seeds = 3,
          },
        },
        second = {
          items = {
            carrot_seeds = 5,
          },
        },
        third = {
          items = {
            sunflower_seeds = 2,
          },
        },
      },
    },
    scenes = {
      finale = "ev_hoestfesten_end",
      opening = "ev_hoestfesten_open",
    },
  },
}
