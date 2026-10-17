-- Calendar and activity schema: towns/social addendum; copy: tools/social/content/festivals.json.
kind = "registry"
registry = "festivals"
festivals = {
  aarsskiftet = {
    activities = {
      {
        id = "year_book",
        kind = "scene",
        name_key = "FEST_AARSSKIFTET_YEAR_BOOK",
        post = "fest_raadhus_host",
      },
      {
        id = "lantern_release",
        kind = "wish",
        name_key = "FEST_AARSSKIFTET_LANTERN_RELEASE",
        post = "fest_raadhus_host",
      },
      {
        id = "midnight_toast",
        kind = "feast",
        name_key = "FEST_AARSSKIFTET_MIDNIGHT_TOAST",
        post = "fest_raadhus_table_1",
      },
    },
    meta = {
      area = "traetoppen",
      attend_points = 20,
      bed_hold = true,
      closes = "all",
      day = 28,
      desc_key = "FEST_AARSSKIFTET_DESC",
      from = 15,
      host = "fairy_king",
      name_key = "FEST_AARSSKIFTET_NAME",
      season = "vinter",
      spot = "raadhus",
      to = 23,
      stays_open = {},
      first = {
        "ghostfam_dyne",
        "ghostfam_gnist",
        "ghostfam_silke",
        "ghostfam_blund",
      },
      leave_early = {
        ghostfam_gnist = 1.5,
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
      finale = "ev_aarsskiftet_end",
      opening = "ev_aarsskiftet_open",
    },
  },
}
