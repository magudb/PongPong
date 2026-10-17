-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_bathkeeper_sofus_h4 = {
    meta = {
      npc = "bathkeeper_sofus",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_badehuset",
      title_key = "HEART_BATHKEEPER_SOFUS_4_TITLE",
      cooldown_days = 1,
      when = "hearts:bathkeeper_sofus:4&hour:8-18&!fest:any&at:bathkeeper_sofus",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "bathkeeper_sofus",
        mark = "tub",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "bathkeeper_sofus",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "bathkeeper_sofus",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_4_01",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_4_02",
      },
      {
        act = "emote",
        who = "bathkeeper_sofus",
        kind = "heart",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_4_03",
      },
      {
        act = "choice",
        who = "bathkeeper_sofus",
        options = {
          {
            id = "stay",
            text_key = "HEART_BATHKEEPER_SOFUS_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BATHKEEPER_SOFUS_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_4_04",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_4_05",
      },
      {
        act = "give",
        item = "apple",
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
  ev_bathkeeper_sofus_h6 = {
    meta = {
      npc = "bathkeeper_sofus",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "int_badehuset",
      title_key = "HEART_BATHKEEPER_SOFUS_6_TITLE",
      cooldown_days = 1,
      when = "hearts:bathkeeper_sofus:6&hour:8-18&!fest:any&at:bathkeeper_sofus",
      after = "ev_bathkeeper_sofus_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "bathkeeper_sofus",
        mark = "tub",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "bathkeeper_sofus",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "bathkeeper_sofus",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_6_01",
      },
      {
        act = "choice",
        who = "bathkeeper_sofus",
        options = {
          {
            id = "stay",
            text_key = "HEART_BATHKEEPER_SOFUS_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BATHKEEPER_SOFUS_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_6_02",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_6_03",
      },
      {
        act = "give",
        item = "cookie",
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
  ev_bathkeeper_sofus_h8 = {
    meta = {
      npc = "bathkeeper_sofus",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_badehuset",
      title_key = "HEART_BATHKEEPER_SOFUS_8_TITLE",
      cooldown_days = 1,
      when = "hearts:bathkeeper_sofus:8&hour:8-18&!fest:any&at:bathkeeper_sofus",
      after = "ev_bathkeeper_sofus_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "bathkeeper_sofus",
        mark = "tub",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "bathkeeper_sofus",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "bathkeeper_sofus",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_8_01",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_8_02",
      },
      {
        act = "emote",
        who = "bathkeeper_sofus",
        kind = "heart",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_8_03",
      },
      {
        act = "choice",
        who = "bathkeeper_sofus",
        options = {
          {
            id = "stay",
            text_key = "HEART_BATHKEEPER_SOFUS_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BATHKEEPER_SOFUS_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_8_04",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_8_05",
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
  ev_bathkeeper_sofus_h10 = {
    meta = {
      npc = "bathkeeper_sofus",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "int_badehuset",
      title_key = "HEART_BATHKEEPER_SOFUS_10_TITLE",
      cooldown_days = 1,
      when = "hearts:bathkeeper_sofus:10&hour:8-18&!fest:any&at:bathkeeper_sofus",
      after = "ev_bathkeeper_sofus_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "bathkeeper_sofus",
        mark = "tub",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "bathkeeper_sofus",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "bathkeeper_sofus",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_10_01",
      },
      {
        act = "choice",
        who = "bathkeeper_sofus",
        options = {
          {
            id = "stay",
            text_key = "HEART_BATHKEEPER_SOFUS_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BATHKEEPER_SOFUS_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_10_02",
      },
      {
        act = "say",
        who = "bathkeeper_sofus",
        text_key = "HEART_BATHKEEPER_SOFUS_10_03",
      },
      {
        act = "give",
        item = "honey_cake",
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
}
