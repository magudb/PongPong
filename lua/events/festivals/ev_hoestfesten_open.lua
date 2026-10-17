-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_hoestfesten_open = {
    meta = {
      trigger = "festival",
      festival = "hoestfesten",
      once_per_year = true,
      area = "traetoppen",
      title_key = "FEST_HOESTFESTEN_NAME",
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
        text_key = "FEST_HOESTFESTEN_OPEN_1",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "FEST_HOESTFESTEN_OPEN_2",
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
