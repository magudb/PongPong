-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_carpenter_brumme_h4 = {
    meta = {
      npc = "carpenter_brumme",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_CARPENTER_BRUMME_4_TITLE",
      cooldown_days = 1,
      when = "hearts:carpenter_brumme:4&hour:8-18&!fest:any&at:carpenter_brumme",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "carpenter_brumme",
        mark = "c_logs",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "carpenter_brumme",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "carpenter_brumme",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_4_01",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_4_02",
      },
      {
        act = "emote",
        who = "carpenter_brumme",
        kind = "heart",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_4_03",
      },
      {
        act = "choice",
        who = "carpenter_brumme",
        options = {
          {
            id = "stay",
            text_key = "HEART_CARPENTER_BRUMME_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_CARPENTER_BRUMME_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_4_04",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_4_05",
      },
      {
        act = "give",
        item = "wood",
        amount = 3,
      },
      {
        act = "camera",
        focus = "player",
        zoom = 0.4,
        time = 0.25,
      },
      {
        act = "end",
      },
    },
    rewards = {
      points = 40,
    },
  },
  ev_carpenter_brumme_h6 = {
    meta = {
      npc = "carpenter_brumme",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_CARPENTER_BRUMME_6_TITLE",
      cooldown_days = 1,
      when = "hearts:carpenter_brumme:6&hour:8-18&!fest:any&at:carpenter_brumme",
      after = "ev_carpenter_brumme_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "carpenter_brumme",
        mark = "c_logs",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "carpenter_brumme",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "carpenter_brumme",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_6_01",
      },
      {
        act = "choice",
        who = "carpenter_brumme",
        options = {
          {
            id = "stay",
            text_key = "HEART_CARPENTER_BRUMME_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_CARPENTER_BRUMME_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_6_02",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_6_03",
      },
      {
        act = "give",
        item = "nails",
        amount = 2,
      },
      {
        act = "camera",
        focus = "player",
        zoom = 0.4,
        time = 0.25,
      },
      {
        act = "end",
      },
    },
    rewards = {
      points = 40,
    },
  },
  ev_carpenter_brumme_h8 = {
    meta = {
      npc = "carpenter_brumme",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_CARPENTER_BRUMME_8_TITLE",
      cooldown_days = 1,
      when = "hearts:carpenter_brumme:8&hour:8-18&!fest:any&at:carpenter_brumme",
      after = "ev_carpenter_brumme_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "carpenter_brumme",
        mark = "c_logs",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "carpenter_brumme",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "carpenter_brumme",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_8_01",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_8_02",
      },
      {
        act = "emote",
        who = "carpenter_brumme",
        kind = "heart",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_8_03",
      },
      {
        act = "choice",
        who = "carpenter_brumme",
        options = {
          {
            id = "stay",
            text_key = "HEART_CARPENTER_BRUMME_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_CARPENTER_BRUMME_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_8_04",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_8_05",
      },
      {
        act = "give",
        item = "honey",
        amount = 1,
      },
      {
        act = "camera",
        focus = "player",
        zoom = 0.4,
        time = 0.25,
      },
      {
        act = "end",
      },
    },
    rewards = {
      points = 40,
    },
  },
  ev_carpenter_brumme_h10 = {
    meta = {
      npc = "carpenter_brumme",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_CARPENTER_BRUMME_10_TITLE",
      cooldown_days = 1,
      when = "hearts:carpenter_brumme:10&hour:8-18&!fest:any&at:carpenter_brumme",
      after = "ev_carpenter_brumme_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "carpenter_brumme",
        mark = "c_logs",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "carpenter_brumme",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "carpenter_brumme",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_10_01",
      },
      {
        act = "choice",
        who = "carpenter_brumme",
        options = {
          {
            id = "stay",
            text_key = "HEART_CARPENTER_BRUMME_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_CARPENTER_BRUMME_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_10_02",
      },
      {
        act = "say",
        who = "carpenter_brumme",
        text_key = "HEART_CARPENTER_BRUMME_10_03",
      },
      {
        act = "give",
        item = "rope",
        amount = 2,
      },
      {
        act = "camera",
        focus = "player",
        zoom = 0.4,
        time = 0.25,
      },
      {
        act = "end",
      },
    },
    rewards = {
      points = 40,
    },
  },
}
