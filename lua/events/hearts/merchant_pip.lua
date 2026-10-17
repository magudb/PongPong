-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_merchant_pip_h4 = {
    meta = {
      npc = "merchant_pip",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_froebutikken",
      title_key = "HEART_MERCHANT_PIP_4_TITLE",
      cooldown_days = 1,
      when = "hearts:merchant_pip:4&hour:8-18&!fest:any&at:merchant_pip",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "merchant_pip",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "merchant_pip",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "merchant_pip",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_4_01",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_4_02",
      },
      {
        act = "emote",
        who = "merchant_pip",
        kind = "heart",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_4_03",
      },
      {
        act = "choice",
        who = "merchant_pip",
        options = {
          {
            id = "stay",
            text_key = "HEART_MERCHANT_PIP_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MERCHANT_PIP_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_4_04",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_4_05",
      },
      {
        act = "give",
        item = "carrot_seeds",
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
  ev_merchant_pip_h6 = {
    meta = {
      npc = "merchant_pip",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "int_froebutikken",
      title_key = "HEART_MERCHANT_PIP_6_TITLE",
      cooldown_days = 1,
      when = "hearts:merchant_pip:6&hour:8-18&!fest:any&at:merchant_pip",
      after = "ev_merchant_pip_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "merchant_pip",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "merchant_pip",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "merchant_pip",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_6_01",
      },
      {
        act = "choice",
        who = "merchant_pip",
        options = {
          {
            id = "stay",
            text_key = "HEART_MERCHANT_PIP_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MERCHANT_PIP_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_6_02",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_6_03",
      },
      {
        act = "give",
        item = "turnip_seeds",
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
  ev_merchant_pip_h8 = {
    meta = {
      npc = "merchant_pip",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_froebutikken",
      title_key = "HEART_MERCHANT_PIP_8_TITLE",
      cooldown_days = 1,
      when = "hearts:merchant_pip:8&hour:8-18&!fest:any&at:merchant_pip",
      after = "ev_merchant_pip_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "merchant_pip",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "merchant_pip",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "merchant_pip",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_8_01",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_8_02",
      },
      {
        act = "emote",
        who = "merchant_pip",
        kind = "heart",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_8_03",
      },
      {
        act = "choice",
        who = "merchant_pip",
        options = {
          {
            id = "stay",
            text_key = "HEART_MERCHANT_PIP_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MERCHANT_PIP_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_8_04",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_8_05",
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
  ev_merchant_pip_h10 = {
    meta = {
      npc = "merchant_pip",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "int_froebutikken",
      title_key = "HEART_MERCHANT_PIP_10_TITLE",
      cooldown_days = 1,
      when = "hearts:merchant_pip:10&hour:8-18&!fest:any&at:merchant_pip",
      after = "ev_merchant_pip_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "merchant_pip",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "merchant_pip",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "merchant_pip",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_10_01",
      },
      {
        act = "choice",
        who = "merchant_pip",
        options = {
          {
            id = "stay",
            text_key = "HEART_MERCHANT_PIP_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_MERCHANT_PIP_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_10_02",
      },
      {
        act = "say",
        who = "merchant_pip",
        text_key = "HEART_MERCHANT_PIP_10_03",
      },
      {
        act = "give",
        item = "moonflower",
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
