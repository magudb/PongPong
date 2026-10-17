-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_baker_maja_h4 = {
    meta = {
      npc = "baker_maja",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_bageriet",
      title_key = "HEART_BAKER_MAJA_4_TITLE",
      cooldown_days = 1,
      when = "hearts:baker_maja:4&hour:8-18&!fest:any&at:baker_maja",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "baker_maja",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "baker_maja",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "baker_maja",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_4_01",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_4_02",
      },
      {
        act = "emote",
        who = "baker_maja",
        kind = "heart",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_4_03",
      },
      {
        act = "choice",
        who = "baker_maja",
        options = {
          {
            id = "stay",
            text_key = "HEART_BAKER_MAJA_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BAKER_MAJA_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_4_04",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_4_05",
      },
      {
        act = "give",
        item = "flour",
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
  ev_baker_maja_h6 = {
    meta = {
      npc = "baker_maja",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "int_bageriet",
      title_key = "HEART_BAKER_MAJA_6_TITLE",
      cooldown_days = 1,
      when = "hearts:baker_maja:6&hour:8-18&!fest:any&at:baker_maja",
      after = "ev_baker_maja_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "baker_maja",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "baker_maja",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "baker_maja",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_6_01",
      },
      {
        act = "choice",
        who = "baker_maja",
        options = {
          {
            id = "stay",
            text_key = "HEART_BAKER_MAJA_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BAKER_MAJA_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_6_02",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_6_03",
      },
      {
        act = "give",
        item = "milk",
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
  ev_baker_maja_h8 = {
    meta = {
      npc = "baker_maja",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_bageriet",
      title_key = "HEART_BAKER_MAJA_8_TITLE",
      cooldown_days = 1,
      when = "hearts:baker_maja:8&hour:8-18&!fest:any&at:baker_maja",
      after = "ev_baker_maja_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "baker_maja",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "baker_maja",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "baker_maja",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_8_01",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_8_02",
      },
      {
        act = "emote",
        who = "baker_maja",
        kind = "heart",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_8_03",
      },
      {
        act = "choice",
        who = "baker_maja",
        options = {
          {
            id = "stay",
            text_key = "HEART_BAKER_MAJA_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BAKER_MAJA_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_8_04",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_8_05",
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
  ev_baker_maja_h10 = {
    meta = {
      npc = "baker_maja",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "int_bageriet",
      title_key = "HEART_BAKER_MAJA_10_TITLE",
      cooldown_days = 1,
      when = "hearts:baker_maja:10&hour:8-18&!fest:any&at:baker_maja",
      after = "ev_baker_maja_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "baker_maja",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "baker_maja",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "baker_maja",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_10_01",
      },
      {
        act = "choice",
        who = "baker_maja",
        options = {
          {
            id = "stay",
            text_key = "HEART_BAKER_MAJA_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_BAKER_MAJA_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_10_02",
      },
      {
        act = "say",
        who = "baker_maja",
        text_key = "HEART_BAKER_MAJA_10_03",
      },
      {
        act = "give",
        item = "cookie",
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
