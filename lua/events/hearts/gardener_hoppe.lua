-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_gardener_hoppe_h4 = {
    meta = {
      npc = "gardener_hoppe",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_GARDENER_HOPPE_4_TITLE",
      cooldown_days = 1,
      when = "hearts:gardener_hoppe:4&hour:8-18&!fest:any&at:gardener_hoppe",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "gardener_hoppe",
        mark = "a_bench",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "gardener_hoppe",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "gardener_hoppe",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_4_01",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_4_02",
      },
      {
        act = "emote",
        who = "gardener_hoppe",
        kind = "heart",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_4_03",
      },
      {
        act = "choice",
        who = "gardener_hoppe",
        options = {
          {
            id = "stay",
            text_key = "HEART_GARDENER_HOPPE_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_GARDENER_HOPPE_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_4_04",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_4_05",
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
  ev_gardener_hoppe_h6 = {
    meta = {
      npc = "gardener_hoppe",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_GARDENER_HOPPE_6_TITLE",
      cooldown_days = 1,
      when = "hearts:gardener_hoppe:6&hour:8-18&!fest:any&at:gardener_hoppe",
      after = "ev_gardener_hoppe_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "gardener_hoppe",
        mark = "a_bench",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "gardener_hoppe",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "gardener_hoppe",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_6_01",
      },
      {
        act = "choice",
        who = "gardener_hoppe",
        options = {
          {
            id = "stay",
            text_key = "HEART_GARDENER_HOPPE_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_GARDENER_HOPPE_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_6_02",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_6_03",
      },
      {
        act = "give",
        item = "fertilizer",
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
  ev_gardener_hoppe_h8 = {
    meta = {
      npc = "gardener_hoppe",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_GARDENER_HOPPE_8_TITLE",
      cooldown_days = 1,
      when = "hearts:gardener_hoppe:8&hour:8-18&!fest:any&at:gardener_hoppe",
      after = "ev_gardener_hoppe_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "gardener_hoppe",
        mark = "a_bench",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "gardener_hoppe",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "gardener_hoppe",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_8_01",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_8_02",
      },
      {
        act = "emote",
        who = "gardener_hoppe",
        kind = "heart",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_8_03",
      },
      {
        act = "choice",
        who = "gardener_hoppe",
        options = {
          {
            id = "stay",
            text_key = "HEART_GARDENER_HOPPE_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_GARDENER_HOPPE_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_8_04",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_8_05",
      },
      {
        act = "give",
        item = "carrot",
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
  ev_gardener_hoppe_h10 = {
    meta = {
      npc = "gardener_hoppe",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "HEART_GARDENER_HOPPE_10_TITLE",
      cooldown_days = 1,
      when = "hearts:gardener_hoppe:10&hour:8-18&!fest:any&at:gardener_hoppe",
      after = "ev_gardener_hoppe_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "gardener_hoppe",
        mark = "a_bench",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "gardener_hoppe",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "gardener_hoppe",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_10_01",
      },
      {
        act = "choice",
        who = "gardener_hoppe",
        options = {
          {
            id = "stay",
            text_key = "HEART_GARDENER_HOPPE_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_GARDENER_HOPPE_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_10_02",
      },
      {
        act = "say",
        who = "gardener_hoppe",
        text_key = "HEART_GARDENER_HOPPE_10_03",
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
