-- Generated from tools/social/content/festivals.json.
kind = "registry"
registry = "events"
events = {
  ev_aarsskiftet_open = {
    meta = {
      trigger = "festival",
      festival = "aarsskiftet",
      once_per_year = true,
      area = "traetoppen",
      title_key = "FEST_AARSSKIFTET_NAME",
    },
    steps = {
      {
        act = "camera",
        focus = "fairy_king",
        zoom = 0.6,
        time = 0.25,
      },
      {
        act = "say",
        who = "fairy_king",
        text_key = "FEST_AARSSKIFTET_OPEN_1",
      },
      {
        act = "say",
        who = "fairy_king",
        text_key = "FEST_AARSSKIFTET_OPEN_2",
      },
      {
        act = "clip",
        who = "fairy_king",
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
