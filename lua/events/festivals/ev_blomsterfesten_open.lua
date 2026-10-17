-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_blomsterfesten_open = {
    meta = {
      trigger = "festival",
      festival = "blomsterfesten",
      once_per_year = true,
      area = "hyggebyen",
      title_key = "FEST_BLOMSTERFESTEN_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "mayor_lyra",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "FEST_BLOMSTERFESTEN_OPEN_1",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "FEST_BLOMSTERFESTEN_OPEN_2",
      },
      {
        act = "clip",
        who = "mayor_lyra",
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
