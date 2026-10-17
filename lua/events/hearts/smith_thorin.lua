-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_smith_thorin_h4 = {
    meta = {
      npc = "smith_thorin",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_smedjen",
      title_key = "HEART_SMITH_THORIN_4_TITLE",
      cooldown_days = 1,
      when = "hearts:smith_thorin:4&hour:8-18&!fest:any&at:smith_thorin",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "smith_thorin",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "smith_thorin",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "smith_thorin",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_4_01",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_4_02",
      },
      {
        act = "emote",
        who = "smith_thorin",
        kind = "heart",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_4_03",
      },
      {
        act = "choice",
        who = "smith_thorin",
        options = {
          {
            id = "stay",
            text_key = "HEART_SMITH_THORIN_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_SMITH_THORIN_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_4_04",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_4_05",
      },
      {
        act = "give",
        item = "copper_ore",
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
  ev_smith_thorin_h6 = {
    meta = {
      npc = "smith_thorin",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "int_smedjen",
      title_key = "HEART_SMITH_THORIN_6_TITLE",
      cooldown_days = 1,
      when = "hearts:smith_thorin:6&hour:8-18&!fest:any&at:smith_thorin",
      after = "ev_smith_thorin_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "smith_thorin",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "smith_thorin",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "smith_thorin",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_6_01",
      },
      {
        act = "choice",
        who = "smith_thorin",
        options = {
          {
            id = "stay",
            text_key = "HEART_SMITH_THORIN_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_SMITH_THORIN_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_6_02",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_6_03",
      },
      {
        act = "give",
        item = "stone",
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
  ev_smith_thorin_h8 = {
    meta = {
      npc = "smith_thorin",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_smedjen",
      title_key = "HEART_SMITH_THORIN_8_TITLE",
      cooldown_days = 1,
      when = "hearts:smith_thorin:8&hour:8-18&!fest:any&at:smith_thorin",
      after = "ev_smith_thorin_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "smith_thorin",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "smith_thorin",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "smith_thorin",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_8_01",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_8_02",
      },
      {
        act = "emote",
        who = "smith_thorin",
        kind = "heart",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_8_03",
      },
      {
        act = "choice",
        who = "smith_thorin",
        options = {
          {
            id = "stay",
            text_key = "HEART_SMITH_THORIN_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_SMITH_THORIN_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_8_04",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_8_05",
      },
      {
        act = "give",
        item = "iron_ore",
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
  ev_smith_thorin_h10 = {
    meta = {
      npc = "smith_thorin",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "int_smedjen",
      title_key = "HEART_SMITH_THORIN_10_TITLE",
      cooldown_days = 1,
      when = "hearts:smith_thorin:10&hour:8-18&!fest:any&at:smith_thorin",
      after = "ev_smith_thorin_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "smith_thorin",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "smith_thorin",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "smith_thorin",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_10_01",
      },
      {
        act = "choice",
        who = "smith_thorin",
        options = {
          {
            id = "stay",
            text_key = "HEART_SMITH_THORIN_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_SMITH_THORIN_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_10_02",
      },
      {
        act = "say",
        who = "smith_thorin",
        text_key = "HEART_SMITH_THORIN_10_03",
      },
      {
        act = "give",
        item = "stone",
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
}
