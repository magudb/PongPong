-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_bagedagen_open = {
    meta = {
      trigger = "festival",
      festival = "bagedagen",
      once_per_year = true,
      area = "hyggebyen",
      title_key = "FEST_BAGEDAGEN_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "baker_maja",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "FEST_BAGEDAGEN_OPEN_1",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "FEST_BAGEDAGEN_OPEN_2",
      },
      {
        act = "clip",
        who = "baker_maja",
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
