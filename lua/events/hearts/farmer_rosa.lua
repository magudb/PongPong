-- Generated from tools/social/content/hearts.json; ordinary friendship scenes.
kind = "registry"
registry = "events"
events = {
  ev_farmer_rosa_h4 = {
    meta = {
      npc = "farmer_rosa",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_dyrehuset",
      title_key = "HEART_FARMER_ROSA_4_TITLE",
      cooldown_days = 1,
      when = "hearts:farmer_rosa:4&hour:8-18&!fest:any&at:farmer_rosa",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "farmer_rosa",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "farmer_rosa",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "farmer_rosa",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_4_01",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_4_02",
      },
      {
        act = "emote",
        who = "farmer_rosa",
        kind = "heart",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_4_03",
      },
      {
        act = "choice",
        who = "farmer_rosa",
        options = {
          {
            id = "stay",
            text_key = "HEART_FARMER_ROSA_4_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_FARMER_ROSA_4_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_4_04",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_4_05",
      },
      {
        act = "give",
        item = "chicken_feed",
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
  ev_farmer_rosa_h6 = {
    meta = {
      npc = "farmer_rosa",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "int_dyrehuset",
      title_key = "HEART_FARMER_ROSA_6_TITLE",
      cooldown_days = 1,
      when = "hearts:farmer_rosa:6&hour:8-18&!fest:any&at:farmer_rosa",
      after = "ev_farmer_rosa_h4",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "farmer_rosa",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "farmer_rosa",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "farmer_rosa",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_6_01",
      },
      {
        act = "choice",
        who = "farmer_rosa",
        options = {
          {
            id = "stay",
            text_key = "HEART_FARMER_ROSA_6_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_FARMER_ROSA_6_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_6_02",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_6_03",
      },
      {
        act = "give",
        item = "animal_treats",
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
  ev_farmer_rosa_h8 = {
    meta = {
      npc = "farmer_rosa",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_dyrehuset",
      title_key = "HEART_FARMER_ROSA_8_TITLE",
      cooldown_days = 1,
      when = "hearts:farmer_rosa:8&hour:8-18&!fest:any&at:farmer_rosa",
      after = "ev_farmer_rosa_h6",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "farmer_rosa",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "farmer_rosa",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "farmer_rosa",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_8_01",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_8_02",
      },
      {
        act = "emote",
        who = "farmer_rosa",
        kind = "heart",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_8_03",
      },
      {
        act = "choice",
        who = "farmer_rosa",
        options = {
          {
            id = "stay",
            text_key = "HEART_FARMER_ROSA_8_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_FARMER_ROSA_8_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_8_04",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_8_05",
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
  ev_farmer_rosa_h10 = {
    meta = {
      npc = "farmer_rosa",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "int_dyrehuset",
      title_key = "HEART_FARMER_ROSA_10_TITLE",
      cooldown_days = 1,
      when = "hearts:farmer_rosa:10&hour:8-18&!fest:any&at:farmer_rosa",
      after = "ev_farmer_rosa_h8",
    },
    steps = {
      {
        act = "fade",
        to = "black",
        time = 0.15,
      },
      {
        act = "stand",
        who = "farmer_rosa",
        mark = "counter",
        facing = "S",
        clear_view = true,
      },
      {
        act = "camera",
        focus = "farmer_rosa",
        zoom = 0.7,
        time = 0.25,
      },
      {
        act = "face",
        who = "farmer_rosa",
        dir = "S",
      },
      {
        act = "fade",
        to = "clear",
        time = 0.15,
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_10_01",
      },
      {
        act = "choice",
        who = "farmer_rosa",
        options = {
          {
            id = "stay",
            text_key = "HEART_FARMER_ROSA_10_CHOICE_1",
            points = 20,
          },
          {
            id = "remember",
            text_key = "HEART_FARMER_ROSA_10_CHOICE_2",
            points = 10,
          },
        },
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_10_02",
      },
      {
        act = "say",
        who = "farmer_rosa",
        text_key = "HEART_FARMER_ROSA_10_03",
      },
      {
        act = "give",
        item = "wool",
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
