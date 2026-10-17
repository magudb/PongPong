-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_honningdagen_end = {
    meta = {
      trigger = "festival",
      festival = "honningdagen",
      once_per_year = true,
      area = "hyggebyen",
      title_key = "FEST_HONNINGDAGEN_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "beekeeper_birk",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "FEST_HONNINGDAGEN_END_1",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "FEST_HONNINGDAGEN_END_2",
      },
      {
        act = "clip",
        who = "beekeeper_birk",
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
