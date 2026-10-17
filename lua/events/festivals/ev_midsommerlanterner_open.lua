-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_midsommerlanterner_open = {
    meta = {
      trigger = "festival",
      festival = "midsommerlanterner",
      once_per_year = true,
      area = "traetoppen",
      title_key = "FEST_MIDSOMMERLANTERNER_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "gardener_hoppe",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "FEST_MIDSOMMERLANTERNER_OPEN_1",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "FEST_MIDSOMMERLANTERNER_OPEN_2",
      },
      {
        act = "clip",
        who = "gardener_hoppe",
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
