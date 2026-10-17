-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_badedagen_open = {
    meta = {
      trigger = "festival",
      festival = "badedagen",
      once_per_year = true,
      area = "traetoppen",
      title_key = "FEST_BADEDAGEN_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "bathkeeper_sofus",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "FEST_BADEDAGEN_OPEN_1",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "FEST_BADEDAGEN_OPEN_2",
      },
      {
        act = "clip",
        who = "bathkeeper_sofus",
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
