-- Enemy movement and attack timings are in ground pixels and seconds.
kind = "config"
config = {
  enemies = {
    bat = { name_key = "ENEMY_BAT", visual = "bat", tint = "ffffff", class = "light", behavior = "chase_lunge", hits_x10 = 6, flying = true, altitude = 73, speed = 175, detect = 550, windup = 0.5, lunge_time = 0.3, lunge_mult = 3.1, recover = 0.7, cooldown = 1.6, trigger_extra = 70, armor = false, ambush_ok = true, drops = {} },
    ugleoje = { name_key = "ENEMY_UGLEOJE", visual = "ugleoje", tint = "ffffff", class = "standard", behavior = "chase_lunge", hits_x10 = 16, flying = false, speed = 160, detect = 550, windup = 0.5, lunge_time = 0.3, lunge_mult = 3.1, recover = 0.7, cooldown = 1.6, trigger_extra = 70, armor = false, ambush_ok = true, drops = {} },
    tornebusk = { name_key = "ENEMY_TORNEBUSK", visual = "tornebusk", tint = "ffffff", class = "heavy", behavior = "stationary", hits_x10 = 24, flying = false, speed = 0, detect = 600, windup = 0.3, lunge_time = 0.15, recover = 0.4, cooldown = 1.6, armor = true, ambush_ok = false, contact = { after = 0.3, radius = 70 }, shoot = { period = 3.5, speed = 260, from_tier = 2 }, drops = { { item = "tornebaer", chance = 0.5, min = 1, max = 1 } } },
    lysesvamp = { name_key = "ENEMY_LYSESVAMP", visual = "lysesvamp", tint = "ffffff", class = "critter", behavior = "flee", hits_x10 = 6, flying = false, speed = 190, detect = 550, armor = false, ambush_ok = false, flee = { speed = 190, radius = 330 }, drops = {} },
    mosfroe = { name_key = "ENEMY_MOSFROE", visual = "frog", tint = "a9c88d", class = "standard", behavior = "hop", hits_x10 = 16, flying = false, speed = 160, detect = 550, windup = 0.5, lunge_time = 0.35, lunge_mult = 3.1, recover = 0.7, cooldown = 1.6, trigger_extra = 70, armor = false, ambush_ok = true, hop = { time = 0.35, distance = 140, pause = 0.2 }, drops = {} },
    sporesvamp = { name_key = "ENEMY_SPORESVAMP", visual = "lysesvamp", tint = "b9a3d4", class = "heavy", behavior = "spore", hits_x10 = 24, flying = false, speed = 0, detect = 650, armor = true, ambush_ok = false, spore = { period = 5.0, ring = 1.0, radius = 150, slow = 40, seconds = 3.0 }, drops = {} },
    krystalugle = { name_key = "ENEMY_KRYSTALUGLE", visual = "ugleoje", tint = "b9dbe8", class = "standard", behavior = "keeper", hits_x10 = 16, flying = false, speed = 160, detect = 750, armor = false, ambush_ok = false, keeper = { distance = 400, line = 0.9, damage = 2, cooldown = 4.0, width = 45, length = 650, seconds = 0.2 }, drops = {} },
  },
}
