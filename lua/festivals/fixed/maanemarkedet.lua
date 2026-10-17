-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  maanemarkedet = {
    activities = {
      {
        id = "moon_market",
        kind = "market",
        name_key = "FEST_MAANEMARKEDET_MOON_MARKET",
        post = "fest_hyggetorv_stall_1",
        shop = "fest_moon_market",
      },
      {
        id = "gem_show",
        kind = "contest",
        name_key = "FEST_MAANEMARKEDET_GEM_SHOW",
        post = "fest_hyggetorv_judge",
        select = "category:gem",
      },
      {
        id = "lantern_wish",
        kind = "wish",
        name_key = "FEST_MAANEMARKEDET_LANTERN_WISH",
        post = "fest_hyggetorv_host",
      },
    },
    meta = {
      area = "hyggebyen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 27,
      desc_key = "FEST_MAANEMARKEDET_DESC",
      from = 18,
      host = "appraiser_fru_ugle",
      name_key = "FEST_MAANEMARKEDET_NAME",
      season = "efteraar",
      spot = "hyggetorv",
      stays_open = {
        "magic_store",
      },
      to = 23,
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
            amethyst = 1,
          },
        },
        second = {
          items = {
            honey = 3,
          },
        },
        third = {
          items = {
            cookie = 3,
          },
        },
      },
    },
    scenes = {
      finale = "ev_maanemarkedet_end",
      opening = "ev_maanemarkedet_open",
    },
  },
}
