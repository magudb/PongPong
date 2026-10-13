-- config/ambient.lua
-- Light, colour and weather rules of the areas (DATA, package P04): read by DayNight (the ONE CanvasModulate of the world),
-- WeatherFx and WorldRoot2D. Designers edit colours and hours here without touching GDScript.
--
-- A map header `@ambient farm|hyggebyen|forest|cave|home` picks a preset below (`@ambient farm_day` etc. work through `aliases`).
-- Colours are hex WITHOUT '#'. A preset's `keys` are { hour, color } keyframes over a 24 hour day (the colour of the
-- CanvasModulate; it MULTIPLIES the picture, so white = unchanged); DayNight interpolates smoothly between them and wraps at
-- midnight. `glow` is the 0..1 factor that fades the additive glow sprites and PointLights in at dusk (lantern posts,
-- windows, mushrooms). The three zone palettes of the style guide are the sources of the colours:
--   Traetoppen   warm honey and moss     (farm)        noon is nearly white, dusk honey-orange, night a cool blue (luminance ~0.4)
--   Hyggebyen    lavender and rose       (hyggebyen)   rose dawn, lavender evening
--   Moerkeskoven navy 1c2138 + mushroom teal 6fd6c4    (forest, cave): a fixed night; the clear colour is the navy itself, the
--                multiplier is the navy lifted so that figures stay readable, and the teal comes from the PointLights.
-- `season` multiplies the preset colour (foraar neutral, sommer warm, efteraar orange, vinter cool; tint only, there are no
-- seasonal tile sets). `weather` multiplies it while that weather lasts (only regn has a visual; fog, snow and thunder are
-- labels only). `weather = false` in a preset means: no rain overlay there (indoors); `wind` is the sideways slant of the rain.
-- `clear` is the engine clear colour (the sky seen behind the backdrop) per preset; `vignette` the strength of the dark
-- screen-edge vignette (0 = none). `area_zone` is the zone id of an area when its map has no @zone header.

kind = "config"

config = {
  ambient = {
    default_preset = "farm",

    aliases = {
      farm_day = "farm",
      hyggebyen_day = "hyggebyen",
      forest_night = "forest",
    },

    area_zone = {
      farm = "farm",
      home = "farm",
      hyggebyen = "city",
      skovkant = "dark_forest",
      dybe_bregner = "dark_forest",
      svampelunden = "mushroom_grove",
      krystalgrotten = "crystal_cave",
    },

    clear = {
      farm = "a9d3e0",
      hyggebyen = "d3c6ee",
      forest = "1c2138",
      cave = "10152a",
      home = "2b2340",
    },

    season = {
      foraar = "ffffff",
      sommer = "fff3d8",
      efteraar = "ffdcb4",
      vinter = "dae8ff",
    },

    weather = {
      klart = "ffffff",
      regn = "d4dbe8",
      taage = "ffffff",
      sne = "ffffff",
      torden = "ffffff",
    },

    presets = {
      farm = {
        name = "farm_day",
        weather = true,
        wind = 1.0,
        vignette = 0.0,
        keys = {
          { hour = 0.0, color = "576199" },
          { hour = 5.0, color = "6b75ad" },
          { hour = 6.5, color = "ffd6bd" },
          { hour = 8.5, color = "fffcf2" },
          { hour = 17.0, color = "fff7eb" },
          { hour = 19.0, color = "ffbd94" },
          { hour = 20.5, color = "9480b8" },
          { hour = 22.0, color = "5e689e" },
          { hour = 24.0, color = "576199" },
        },
        glow = {
          { hour = 0.0, v = 1.0 },
          { hour = 5.5, v = 1.0 },
          { hour = 7.0, v = 0.0 },
          { hour = 17.5, v = 0.0 },
          { hour = 19.5, v = 1.0 },
          { hour = 24.0, v = 1.0 },
        },
      },

      hyggebyen = {
        name = "hyggebyen_day",
        weather = true,
        wind = 0.8,
        vignette = 0.0,
        keys = {
          { hour = 0.0, color = "5a5a98" },
          { hour = 5.0, color = "7a78b4" },
          { hour = 6.5, color = "ffd0dc" },
          { hour = 8.5, color = "fbf4ff" },
          { hour = 17.0, color = "f7efff" },
          { hour = 19.0, color = "ffb8cc" },
          { hour = 20.5, color = "a58bd0" },
          { hour = 22.0, color = "625d9c" },
          { hour = 24.0, color = "5a5a98" },
        },
        glow = {
          { hour = 0.0, v = 1.0 },
          { hour = 5.5, v = 1.0 },
          { hour = 7.0, v = 0.0 },
          { hour = 17.5, v = 0.0 },
          { hour = 19.5, v = 1.0 },
          { hour = 24.0, v = 1.0 },
        },
      },

      forest = {
        name = "forest_night",
        weather = false,
        wind = 0.0,
        vignette = 0.78,
        keys = {
          { hour = 0.0, color = "4d5e85" },
          { hour = 24.0, color = "4d5e85" },
        },
        glow = {
          { hour = 0.0, v = 1.0 },
          { hour = 24.0, v = 1.0 },
        },
      },

      cave = {
        name = "cave",
        weather = false,
        wind = 0.0,
        vignette = 0.85,
        keys = {
          { hour = 0.0, color = "343b5c" },
          { hour = 24.0, color = "343b5c" },
        },
        glow = {
          { hour = 0.0, v = 1.0 },
          { hour = 24.0, v = 1.0 },
        },
      },

      -- indoors (the home interior, F6): warm light, no weather overlay, no wind, lamp halos always on
      home = {
        name = "home",
        weather = false,
        wind = 0.0,
        vignette = 0.0,
        keys = {
          { hour = 0.0, color = "e6cba8" },
          { hour = 6.5, color = "fff0d6" },
          { hour = 17.0, color = "fff0d6" },
          { hour = 21.0, color = "ecd2ad" },
          { hour = 24.0, color = "e6cba8" },
        },
        glow = {
          { hour = 0.0, v = 1.0 },
          { hour = 24.0, v = 1.0 },
        },
      },
    },
  },
}
