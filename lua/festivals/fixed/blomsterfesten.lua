-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  blomsterfesten = {
    activities = {
      {
        id = "flower_contest",
        kind = "contest",
        name_key = "FEST_BLOMSTERFESTEN_FLOWER_CONTEST",
        post = "fest_hyggetorv_judge",
        select = "category:forage",
      },
      {
        id = "seed_stall",
        kind = "market",
        name_key = "FEST_BLOMSTERFESTEN_SEED_STALL",
        post = "fest_hyggetorv_stall_1",
        shop = "fest_flower_market",
      },
      {
        id = "dance",
        kind = "dance",
        name_key = "FEST_BLOMSTERFESTEN_DANCE",
        post = "fest_hyggetorv_host",
      },
    },
    meta = {
      area = "hyggebyen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 7,
      desc_key = "FEST_BLOMSTERFESTEN_DESC",
      from = 12,
      host = "mayor_lyra",
      name_key = "FEST_BLOMSTERFESTEN_NAME",
      season = "foraar",
      spot = "hyggetorv",
      stays_open = {},
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
            sunflower_seeds = 4,
          },
        },
        second = {
          items = {
            sunflower_seeds = 2,
          },
        },
        third = {
          items = {
            sunflower_seeds = 1,
          },
        },
      },
    },
    scenes = {
      finale = "ev_blomsterfesten_end",
      opening = "ev_blomsterfesten_open",
    },
  },
}
