-- shops/smithy.lua
-- Smeden Thorins smedje (keeper smith_thorin) (P12).  kind = "shops"; the fields are explained in seed_shop.lua.
-- Iron tools and the iron sword: the upgrades of the starter kit (hoe 1 -> 2, watering can 1 -> 2, pickaxe -> 3, sword 5 -> 12).

kind = "shops"

shops = {
  smithy = {
    name_key = "SHOP_SMITHY",
    keeper = "smith_thorin",
    greeting_key = "SHOP_SMITHY_GREETING",
    buy_multiplier = 1.0,
    sell_multiplier = 1.0,
    rotation = {
      { id = "smedens_udvalg", period = 3, pick = 4, qty = 1, rarity = "mixed", price_mult = 1.0, season_boost = 1.0,
        pool = { "wpn_dagger_thorn", "wpn_dagger_flint", "wpn_club_spruce", "wpn_club_oak", "wpn_spear_twig", "wpn_spear_iron", "wpn_staff_branch", "wpn_staff_hazel" } },
      { id = "ugens_staal", period = 7, pick = 2, qty = 1, rarity = "rare", price_mult = 1.1, season_boost = 1.0,
        pool = { "wpn_dagger_moonshard", "wpn_sword_forest_steel", "wpn_club_mushroom", "wpn_spear_thistle", "wpn_staff_light" } },
    },
    stock = {
      hoe_iron = { stock = 2, restock = 1 },
      pickaxe_iron = { stock = 2, restock = 1 },
      watering_can_gold = { stock = 1, restock = 1 },
      iron_sword = { stock = 1, restock = 1 },
    },
  },
}
