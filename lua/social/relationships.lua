-- Dynamic wedding date and first guest are derived from the saved partner.
kind = "config"
config = { relationships = {
  heartfriend_hearts = 8,
  engagement_hearts = 10,
  heartfriend_days = 7,
  min_home_tier = 3,
  wedding_wait = 7,
  wedding = {
    meta = {
      area = "hyggebyen",
      spot = "hyggetorv",
      host = "mayor_lyra",
      name_key = "FEST_BRYLLUPSFESTEN_NAME",
      desc_key = "FEST_BRYLLUPSFESTEN_DESC",
      season = "foraar",
      day = 1,
      from = 12,
      to = 20,
      closes = "all",
      bed_hold = true,
      guests = {
        "ghostfam_dyne",
        "ghostfam_gnist",
        "ghostfam_silke",
        "ghostfam_blund",
      },
      leave_early = {
        ghostfam_gnist = 1.25,
      },
    },
    activities = {
      {
        id = "dance",
        kind = "dance",
        name_key = "FEST_BRYLLUPSFESTEN_DANCE",
        post = "fest_hyggetorv_host",
      },
    },
  },
} }
