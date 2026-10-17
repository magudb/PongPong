-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_mayor_lyra_h4 = {
    meta = {
      npc = "mayor_lyra",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_MAYOR_LYRA_4_TITLE",
      cooldown_days = 1,
      when = "hearts:mayor_lyra:4&hour:8-18&!fest:any&at:mayor_lyra",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "mayor_lyra",
        mark = "torv_fountain_n",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "mayor_lyra",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "mayor_lyra",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_4_01",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_4_02",
      },
      {
        act = "emote",
        who = "mayor_lyra",
        kind = "heart",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_4_03",
      },
      {
        act = "choice",
        who = "mayor_lyra",
        options = {
          {
            id = "stay",
            text_key = "HEART_MAYOR_LYRA_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MAYOR_LYRA_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_4_04",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_4_05",
      },
      {
        act = "give",
        item = "wild_flower",
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
  ev_mayor_lyra_h6 = {
    meta = {
      npc = "mayor_lyra",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_MAYOR_LYRA_6_TITLE",
      cooldown_days = 1,
      when = "hearts:mayor_lyra:6&hour:8-18&!fest:any&at:mayor_lyra",
      after = "ev_mayor_lyra_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "mayor_lyra",
        mark = "torv_fountain_n",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "mayor_lyra",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "mayor_lyra",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_6_01",
      },
      {
        act = "choice",
        who = "mayor_lyra",
        options = {
          {
            id = "stay",
            text_key = "HEART_MAYOR_LYRA_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MAYOR_LYRA_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_6_02",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_6_03",
      },
      {
        act = "give",
        item = "wood",
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
  ev_mayor_lyra_h8 = {
    meta = {
      npc = "mayor_lyra",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_MAYOR_LYRA_8_TITLE",
      cooldown_days = 1,
      when = "hearts:mayor_lyra:8&hour:8-18&!fest:any&at:mayor_lyra",
      after = "ev_mayor_lyra_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "mayor_lyra",
        mark = "torv_fountain_n",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "mayor_lyra",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "mayor_lyra",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_8_01",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_8_02",
      },
      {
        act = "emote",
        who = "mayor_lyra",
        kind = "heart",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_8_03",
      },
      {
        act = "choice",
        who = "mayor_lyra",
        options = {
          {
            id = "stay",
            text_key = "HEART_MAYOR_LYRA_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MAYOR_LYRA_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_8_04",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_8_05",
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
  ev_mayor_lyra_h10 = {
    meta = {
      npc = "mayor_lyra",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_MAYOR_LYRA_10_TITLE",
      cooldown_days = 1,
      when = "hearts:mayor_lyra:10&hour:8-18&!fest:any&at:mayor_lyra",
      after = "ev_mayor_lyra_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "mayor_lyra",
        mark = "torv_fountain_n",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "mayor_lyra",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "mayor_lyra",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_10_01",
      },
      {
        act = "choice",
        who = "mayor_lyra",
        options = {
          {
            id = "stay",
            text_key = "HEART_MAYOR_LYRA_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MAYOR_LYRA_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_10_02",
      },
      {
        act = "say",
        who = "mayor_lyra",
        text_key = "HEART_MAYOR_LYRA_10_03",
      },
      {
        act = "give",
        item = "wild_flower",
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
