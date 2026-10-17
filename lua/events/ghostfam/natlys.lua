-- Generated from tools/social/content/natlys.json.
kind = "registry"
registry = "events"
events = {
  ev_ghostfam_dyne_h4 = {
    meta = {
      npc = "ghostfam_dyne",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_DYNE_H4_TITLE",
      cooldown_days = 1,
      when = "hour:19-22&!fest:any&at:ghostfam_dyne",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:t_fire_e",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_dyne",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H4_1",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H4_2",
      },
      {
        act = "emote",
        who = "ghostfam_dyne",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H4_3",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H4_4",
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
  ev_ghostfam_dyne_h6 = {
    meta = {
      npc = "ghostfam_dyne",
      hearts = 6,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_DYNE_H6_TITLE",
      cooldown_days = 1,
      when = "weekday:2&hour:19-22&!fest:any&at:ghostfam_dyne&at:ghostfam_gnist&at:ghostfam_silke&at:ghostfam_blund",
      after = "ev_ghostfam_dyne_h4",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:t_fire_e",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_dyne",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_gnist",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_silke",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_blund",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H6_1",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H6_2",
      },
      {
        act = "emote",
        who = "ghostfam_dyne",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H6_3",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H6_4",
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
  ev_ghostfam_dyne_h8 = {
    meta = {
      npc = "ghostfam_dyne",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_DYNE_H8_TITLE",
      cooldown_days = 1,
      when = "hour:24-25.5&!fest:any&at:ghostfam_dyne",
      after = "ev_ghostfam_dyne_h6",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:f_bench",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_dyne",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H8_1",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H8_2",
      },
      {
        act = "emote",
        who = "ghostfam_dyne",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H8_3",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H8_4",
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
  ev_ghostfam_dyne_h10 = {
    meta = {
      npc = "ghostfam_dyne",
      hearts = 10,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_DYNE_H10_TITLE",
      cooldown_days = 1,
      when = "hour:19-22&!fest:any&!flag:ghostfam_kin_dyne&!flag:natlys_seat&at:ghostfam_dyne",
      after = "ev_ghostfam_dyne_h8",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:t_fire_e",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_dyne",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H10_1",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H10_2",
      },
      {
        act = "emote",
        who = "ghostfam_dyne",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_DYNE_H10_3",
      },
      {
        act = "flag",
        key = "natlys_seat",
        value = true,
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
      points = 100,
    },
  },
  ev_ghostfam_gnist_h4 = {
    meta = {
      npc = "ghostfam_gnist",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "int_gaestehytten",
      title_key = "GF_EVENT_GHOSTFAM_GNIST_H4_TITLE",
      cooldown_days = 1,
      when = "hour:17-25&!fest:any&at:ghostfam_gnist",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:counter",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_gnist",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H4_1",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H4_2",
      },
      {
        act = "emote",
        who = "ghostfam_gnist",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H4_3",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H4_4",
      },
      {
        act = "give",
        item = "lantern_oil",
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
  ev_ghostfam_gnist_h8 = {
    meta = {
      npc = "ghostfam_gnist",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "int_gaestehytten",
      title_key = "GF_EVENT_GHOSTFAM_GNIST_H8_TITLE",
      cooldown_days = 1,
      when = "hour:24.5-25&!fest:any&at:ghostfam_gnist",
      after = "ev_ghostfam_gnist_h4",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:counter",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_gnist",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H8_1",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H8_2",
      },
      {
        act = "emote",
        who = "ghostfam_gnist",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_GNIST_H8_3",
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
  ev_ghostfam_silke_h4 = {
    meta = {
      npc = "ghostfam_silke",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "hyggebyen",
      title_key = "GF_EVENT_GHOSTFAM_SILKE_H4_TITLE",
      cooldown_days = 1,
      when = "hour:20.1-20.65&!weekday:2&!fest:any&at:ghostfam_silke",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:round_s",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_silke",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H4_1",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H4_2",
      },
      {
        act = "emote",
        who = "ghostfam_silke",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H4_3",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H4_4",
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
  ev_ghostfam_silke_h8 = {
    meta = {
      npc = "ghostfam_silke",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_SILKE_H8_TITLE",
      cooldown_days = 1,
      when = "hour:6-6.4&!fest:any&at:ghostfam_silke",
      after = "ev_ghostfam_silke_h4",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:f_lamp",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_silke",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H8_1",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H8_2",
      },
      {
        act = "emote",
        who = "ghostfam_silke",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H8_3",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_SILKE_H8_4",
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
  ev_ghostfam_blund_h4 = {
    meta = {
      npc = "ghostfam_blund",
      hearts = 4,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_BLUND_H4_TITLE",
      cooldown_days = 1,
      when = "weekday:0&hour:18-20.5&!fest:any&at:ghostfam_blund",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:g_planter2",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_blund",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H4_1",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H4_2",
      },
      {
        act = "emote",
        who = "ghostfam_blund",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H4_3",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H4_4",
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
  ev_ghostfam_blund_h8 = {
    meta = {
      npc = "ghostfam_blund",
      hearts = 8,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_BLUND_H8_TITLE",
      cooldown_days = 1,
      when = "weekday:2&hour:19-23&!fest:any&at:ghostfam_blund",
      after = "ev_ghostfam_blund_h4",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:t_fire_s",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_blund",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H8_1",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H8_2",
        when = "flag:ghostfam_kin_blund",
      },
      {
        act = "emote",
        who = "ghostfam_blund",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H8_3",
        when = "!flag:ghostfam_kin_blund",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H8_4",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_BLUND_H8_5",
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
  ev_ghostfam_kin_welcome = {
    meta = {
      npc = "ghostfam_dyne",
      hearts = 2,
      trigger = "talk",
      once = true,
      area = "traetoppen",
      title_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_TITLE",
      cooldown_days = 1,
      when = "flag:ghostfam_kin_dyne&!flag:natlys_seat&weekday:2&hour:19-23&!fest:any&at:ghostfam_dyne&at:ghostfam_gnist&at:ghostfam_silke&at:ghostfam_blund",
    },
    steps = {
      {
        act = "camera",
        focus = "mark:t_fire_e",
        zoom = 0.65,
        time = 0.25,
      },
      {
        act = "face",
        who = "ghostfam_dyne",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_gnist",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_silke",
        dir = "S",
      },
      {
        act = "face",
        who = "ghostfam_blund",
        dir = "S",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_1",
      },
      {
        act = "say",
        who = "ghostfam_silke",
        text_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_2",
      },
      {
        act = "emote",
        who = "ghostfam_dyne",
        kind = "heart",
      },
      {
        act = "say",
        who = "ghostfam_gnist",
        text_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_3",
      },
      {
        act = "say",
        who = "ghostfam_blund",
        text_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_4",
      },
      {
        act = "say",
        who = "ghostfam_dyne",
        text_key = "GF_EVENT_GHOSTFAM_KIN_WELCOME_5",
      },
      {
        act = "flag",
        key = "natlys_seat",
        value = true,
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
      points = 100,
    },
  },
}
