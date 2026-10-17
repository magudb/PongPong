-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_vinterlysene_end = {
    meta = {
      trigger = "festival",
      festival = "vinterlysene",
      once_per_year = true,
      area = "traetoppen",
      title_key = "FEST_VINTERLYSENE_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "fairy_lily",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "fairy_lily",
        text_key = "FEST_VINTERLYSENE_END_1",
      },
      {
        act = "say",
        who = "fairy_lily",
        text_key = "FEST_VINTERLYSENE_END_2",
      },
      {
        act = "clip",
        who = "fairy_lily",
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
