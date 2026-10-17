-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_maanemarkedet_end = {
    meta = {
      trigger = "festival",
      festival = "maanemarkedet",
      once_per_year = true,
      area = "hyggebyen",
      title_key = "FEST_MAANEMARKEDET_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "appraiser_fru_ugle",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "appraiser_fru_ugle",
        text_key = "FEST_MAANEMARKEDET_END_1",
      },
      {
        act = "say",
        who = "appraiser_fru_ugle",
        text_key = "FEST_MAANEMARKEDET_END_2",
      },
      {
        act = "clip",
        who = "appraiser_fru_ugle",
        clip = "celebrate",
      },
      {
        act = "camera",
        focus = "player",
        zoom = 0.4,
        time = 0.25,
      },
    },
    rewards = {
      points = 0,
    },
  },
}
