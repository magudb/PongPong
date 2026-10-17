-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  honningdagen = {
    activities = {
      {
        id = "honey_contest",
        kind = "contest",
        name_key = "FEST_HONNINGDAGEN_HONEY_CONTEST",
        post = "fest_hyggetorv_judge",
        select = "category:food",
      },
      {
        id = "picnic",
        kind = "feast",
        name_key = "FEST_HONNINGDAGEN_PICNIC",
        post = "fest_hyggetorv_table_1",
      },
      {
        id = "honey_stall",
        kind = "market",
        name_key = "FEST_HONNINGDAGEN_HONEY_STALL",
        post = "fest_hyggetorv_stall_1",
        shop = "fest_honey_market",
      },
    },
    meta = {
      area = "hyggebyen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 21,
      desc_key = "FEST_HONNINGDAGEN_DESC",
      from = 11,
      host = "beekeeper_birk",
      name_key = "FEST_HONNINGDAGEN_NAME",
      season = "foraar",
      spot = "hyggetorv",
      stays_open = {
        "bakery",
      },
      to = 19,
      guests = {
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
            honey = 2,
          },
        },
        second = {
          items = {
            cookie = 1,
          },
        },
        third = {
          items = {
            carrot_seeds = 1,
          },
        },
      },
    },
    scenes = {
      finale = "ev_honningdagen_end",
      opening = "ev_honningdagen_open",
    },
  },
}
