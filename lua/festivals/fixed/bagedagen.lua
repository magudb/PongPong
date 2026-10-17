-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  bagedagen = {
    activities = {
      {
        id = "cookie_contest",
        kind = "contest",
        name_key = "FEST_BAGEDAGEN_COOKIE_CONTEST",
        post = "fest_hyggetorv_judge",
        select = "category:food",
      },
      {
        id = "tasting_table",
        kind = "feast",
        name_key = "FEST_BAGEDAGEN_TASTING_TABLE",
        post = "fest_hyggetorv_table_1",
      },
      {
        id = "bake_stall",
        kind = "market",
        name_key = "FEST_BAGEDAGEN_BAKE_STALL",
        post = "fest_hyggetorv_stall_1",
        shop = "fest_bake_market",
      },
    },
    meta = {
      area = "hyggebyen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 21,
      desc_key = "FEST_BAGEDAGEN_DESC",
      from = 12,
      host = "baker_maja",
      name_key = "FEST_BAGEDAGEN_NAME",
      season = "vinter",
      spot = "hyggetorv",
      stays_open = {
        "bakery",
      },
      to = 20,
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
            honey = 3,
          },
        },
        second = {
          items = {
            cookie = 2,
          },
        },
        third = {
          items = {
            carrot_seeds = 2,
          },
        },
      },
    },
    scenes = {
      finale = "ev_bagedagen_end",
      opening = "ev_bagedagen_open",
    },
  },
}
