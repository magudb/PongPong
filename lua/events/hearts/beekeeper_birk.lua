-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_beekeeper_birk_h4 = {
    meta = {
      npc = "beekeeper_birk",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_BEEKEEPER_BIRK_4_TITLE",
      cooldown_days = 1,
      when = "hearts:beekeeper_birk:4&hour:8-18&!fest:any&at:beekeeper_birk",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "beekeeper_birk",
        mark = "bees1",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "beekeeper_birk",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "beekeeper_birk",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_4_01",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_4_02",
      },
      {
        act = "emote",
        who = "beekeeper_birk",
        kind = "heart",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_4_03",
      },
      {
        act = "choice",
        who = "beekeeper_birk",
        options = {
          {
            id = "stay",
            text_key = "HEART_BEEKEEPER_BIRK_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BEEKEEPER_BIRK_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_4_04",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_4_05",
      },
      {
        act = "give",
        item = "sunflower_seeds",
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
  ev_beekeeper_birk_h6 = {
    meta = {
      npc = "beekeeper_birk",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_BEEKEEPER_BIRK_6_TITLE",
      cooldown_days = 1,
      when = "hearts:beekeeper_birk:6&hour:8-18&!fest:any&at:beekeeper_birk",
      after = "ev_beekeeper_birk_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "beekeeper_birk",
        mark = "bees1",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "beekeeper_birk",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "beekeeper_birk",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_6_01",
      },
      {
        act = "choice",
        who = "beekeeper_birk",
        options = {
          {
            id = "stay",
            text_key = "HEART_BEEKEEPER_BIRK_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BEEKEEPER_BIRK_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_6_02",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_6_03",
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
  ev_beekeeper_birk_h8 = {
    meta = {
      npc = "beekeeper_birk",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_BEEKEEPER_BIRK_8_TITLE",
      cooldown_days = 1,
      when = "hearts:beekeeper_birk:8&hour:8-18&!fest:any&at:beekeeper_birk",
      after = "ev_beekeeper_birk_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "beekeeper_birk",
        mark = "bees1",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "beekeeper_birk",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "beekeeper_birk",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_8_01",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_8_02",
      },
      {
        act = "emote",
        who = "beekeeper_birk",
        kind = "heart",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_8_03",
      },
      {
        act = "choice",
        who = "beekeeper_birk",
        options = {
          {
            id = "stay",
            text_key = "HEART_BEEKEEPER_BIRK_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BEEKEEPER_BIRK_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_8_04",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_8_05",
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
  ev_beekeeper_birk_h10 = {
    meta = {
      npc = "beekeeper_birk",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "HEART_BEEKEEPER_BIRK_10_TITLE",
      cooldown_days = 1,
      when = "hearts:beekeeper_birk:10&hour:8-18&!fest:any&at:beekeeper_birk",
      after = "ev_beekeeper_birk_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "beekeeper_birk",
        mark = "bees1",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "beekeeper_birk",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "beekeeper_birk",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_10_01",
      },
      {
        act = "choice",
        who = "beekeeper_birk",
        options = {
          {
            id = "stay",
            text_key = "HEART_BEEKEEPER_BIRK_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BEEKEEPER_BIRK_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_10_02",
      },
      {
        act = "say",
        who = "beekeeper_birk",
        text_key = "HEART_BEEKEEPER_BIRK_10_03",
      },
      {
        act = "give",
        item = "sunflower",
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
