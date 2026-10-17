-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  badedagen = {
    activities = {
      {
        id = "free_bath",
        kind = "feast",
        name_key = "FEST_BADEDAGEN_FREE_BATH",
        post = "fest_badehus_host",
      },
      {
        id = "picnic",
        kind = "feast",
        name_key = "FEST_BADEDAGEN_PICNIC",
        post = "fest_badehus_table_1",
      },
      {
        id = "potluck",
        kind = "potluck",
        name_key = "FEST_BADEDAGEN_POTLUCK",
        post = "fest_badehus_table_2",
        select = "category:food",
      },
    },
    meta = {
      area = "traetoppen",
      attend_points = 20,
      bed_hold = true,
      closes = "none",
      day = 27,
      desc_key = "FEST_BADEDAGEN_DESC",
      from = 10,
      host = "bathkeeper_sofus",
      name_key = "FEST_BADEDAGEN_NAME",
      season = "sommer",
      spot = "badehus",
      to = 18,
      stays_open = {},
      first = {
        "ghostfam_dyne",
        "ghostfam_gnist",
        "ghostfam_silke",
        "ghostfam_blund",
      },
      leave_early = {
        ghostfam_gnist = 2.75,
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
      potluck = {
        items = {
          cookie = 2,
        },
      },
    },
    scenes = {
      finale = "ev_badedagen_end",
      opening = "ev_badedagen_open",
    },
  },
}
