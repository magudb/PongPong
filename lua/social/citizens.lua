-- social/citizens.lua
-- Social facts of every citizen who can reach hearts.  ONE config key: citizens.  The NPC itself (name, art, voice, home area,
-- shop) stays in lua/config/npcs.lua; this table only adds what the social layer needs.  A NPC without a row here still works:
-- SocialData derives tier C, archetype role_archetype[role], a stable birthday from the id and universal tastes; the validator
-- (tools/social/validate_social.py) warns "derived" so a real row can be added later.  Fields:
--   tier       A hjertefolk (full authored depth) | B byfolk | C smaafolk (archetype pools, short texts)
--   archetype  taste archetype + SOC_ARCH_<ARCH>_* line pools + voice preset
--   birthday   { season = foraar|sommer|efteraar|vinter, day = 1..28 }   (never on a festival day: validator rule)
--   partner    true = may enter the marriage-style track (LATER package S-marriage), never gated by gender
--   unlock     OPTIONAL { quest = "<id>", day = <n> }: the NPC cannot be befriended before the quest is done OR total_day >= day (Morfar Mis: lost_cat or day 60, towns track gate)
kind = "config"

config = {
  citizens = {
    mayor_lyra = { tier = "A", archetype = "fairy", birthday = { season = "vinter", day = 1 }, partner = false },
    baker_maja = { tier = "A", archetype = "shopkeeper", birthday = { season = "efteraar", day = 10 }, partner = true , sample = { item = "cookie", from_hearts = 2 } },
    merchant_pip = { tier = "A", archetype = "shopkeeper", birthday = { season = "foraar", day = 3 }, partner = true , sample = { item = "carrot_seeds", from_hearts = 2 } },
    gardener_hoppe = { tier = "A", archetype = "gardener", birthday = { season = "foraar", day = 5 }, partner = true },
    carpenter_brumme = { tier = "A", archetype = "craftsman", birthday = { season = "sommer", day = 8 }, partner = true },
    postman_pip = { tier = "A", archetype = "wanderer", birthday = { season = "foraar", day = 19 }, partner = true },
    bathkeeper_sofus = { tier = "A", archetype = "elder", birthday = { season = "sommer", day = 12 }, partner = true },
    beekeeper_birk = { tier = "A", archetype = "gardener", birthday = { season = "sommer", day = 6 }, partner = true },
    smith_thorin = { tier = "A", archetype = "craftsman", birthday = { season = "sommer", day = 21 }, partner = false , sample = { item = "stone", from_hearts = 3 } },
    farmer_rosa = { tier = "A", archetype = "gardener", birthday = { season = "foraar", day = 13 }, partner = false , sample = { item = "chicken_feed", from_hearts = 2 } },
    pippin_boegeknop = { tier = "B", archetype = "wanderer", birthday = { season = "efteraar", day = 1 }, partner = false , sample = { item = "cookie", from_hearts = 2 } },
    -- Day one follows the year-end festival. Day nine preserves the two-day gap.
    fairy_lily = { tier = "B", archetype = "child", birthday = { season = "foraar", day = 9 }, partner = false },
    guard_oak = { tier = "B", archetype = "watcher", birthday = { season = "sommer", day = 24 }, partner = false },
    fairy_wizard = { tier = "B", archetype = "elder", birthday = { season = "efteraar", day = 7 }, partner = false , sample = { item = "glow_mushroom", from_hearts = 3 } },
    fairy_builder = { tier = "B", archetype = "craftsman", birthday = { season = "efteraar", day = 24 }, partner = false , sample = { item = "nails", from_hearts = 3 } },
    fairy_furnisher = { tier = "B", archetype = "fairy", birthday = { season = "efteraar", day = 22 }, partner = false , sample = { item = "wild_flower", from_hearts = 3 } },
    fairy_tailor = { tier = "B", archetype = "fairy", birthday = { season = "vinter", day = 23 }, partner = false , sample = { item = "fabric_plain", from_hearts = 3 } },
    appraiser_fru_ugle = { tier = "B", archetype = "elder", birthday = { season = "vinter", day = 16 }, partner = false },
    mapseller_natteblik = { tier = "B", archetype = "watcher", birthday = { season = "efteraar", day = 18 }, partner = false },
    fairy_king = { tier = "B", archetype = "elder", birthday = { season = "vinter", day = 4 }, partner = false },
    rasmus = { tier = "B", archetype = "wanderer", birthday = { season = "sommer", day = 2 }, partner = true },
    lamplighter_kiki = { tier = "B", archetype = "wanderer", birthday = { season = "foraar", day = 11 }, partner = true },
    bertil = { tier = "B", archetype = "gardener", birthday = { season = "efteraar", day = 20 }, partner = true },
    bodil = { tier = "B", archetype = "gardener", birthday = { season = "foraar", day = 28 }, partner = true },
    cat_morfar_mis = { tier = "C", archetype = "elder", birthday = { season = "vinter", day = 13 }, partner = false, unlock = { quest = "lost_cat", day = 60 } },
    penguin_postman = { tier = "C", archetype = "wanderer", birthday = { season = "sommer", day = 10 }, partner = false },
    innkeeper_kvak = { tier = "B", archetype = "shopkeeper", birthday = { season = "efteraar", day = 12 }, partner = false },
    cub_bamse = { tier = "C", archetype = "child", birthday = { season = "sommer", day = 4 }, partner = false },
    clerk_fjerpen = { tier = "C", archetype = "watcher", birthday = { season = "foraar", day = 16 }, partner = false },
    fiddler_strimmel = { tier = "C", archetype = "wanderer", birthday = { season = "vinter", day = 18 }, partner = false },
      ghostfam_dyne = { tier = "A", archetype = "elder", birthday = { season = "vinter", day = 10 }, partner = false },
    ghostfam_gnist = { tier = "B", archetype = "shopkeeper", birthday = { season = "efteraar", day = 4 }, partner = false },
    ghostfam_silke = { tier = "B", archetype = "watcher", birthday = { season = "sommer", day = 19 }, partner = false },
    ghostfam_blund = { tier = "B", archetype = "child", birthday = { season = "foraar", day = 23 }, partner = false },
},
}
