-- Runtime light effects reuse Glow textures; the approved painted bodies are untouched.
kind = "config"
config = { npc_glow = {
  ghostfam_dyne = { halo = { color = "f1c9df", alpha = 0.9, scale = 1.25, x = 0, y = -70 } },
  ghostfam_gnist = { halo = { color = "c3e5d2", alpha = 0.9, scale = 1.25, x = 0, y = -70 } },
  ghostfam_silke = { halo = { color = "bfe0ff", alpha = 0.9, scale = 1.25, x = 0, y = -70 },
    light = { texture_scale = 0.45, energy = 0.30, color = "ffd98a", x = 34, y = -22 } },
  ghostfam_blund = { halo = { color = "ffe6aa", alpha = 0.9, scale = 1.25, x = 0, y = -70 } },
} }
