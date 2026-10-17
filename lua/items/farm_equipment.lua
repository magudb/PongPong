-- Craftable farm equipment and the processed output catalog.
-- Preserves sell for 2x crop value + 50; juice for 3x crop value.
kind = "items"
items = {
  sprinkler = { name_key = "ITEM_SPRINKLER", description_key = "ITEM_SPRINKLER_DESC", category = "placeable", placeable = "farm", farm_machine = "sprinkler", prop = "sprinkler", stamina_cost = 1, rarity = "normal", max_stack = 20, buy_price = 300, sell_price = 75 },
  quality_sprinkler = { name_key = "ITEM_QUALITY_SPRINKLER", description_key = "ITEM_QUALITY_SPRINKLER_DESC", category = "placeable", placeable = "farm", farm_machine = "quality_sprinkler", prop = "sprinkler", stamina_cost = 1, rarity = "uncommon", max_stack = 20, buy_price = 800, sell_price = 200 },
  preserves_jar = { name_key = "ITEM_PRESERVES_JAR", description_key = "ITEM_PRESERVES_JAR_DESC", category = "placeable", placeable = "farm", farm_machine = "preserves_jar", prop = "preserves_jar", stamina_cost = 1, rarity = "normal", max_stack = 20, buy_price = 350, sell_price = 87 },
  keg = { name_key = "ITEM_KEG", description_key = "ITEM_KEG_DESC", category = "placeable", placeable = "farm", farm_machine = "keg", prop = "keg", stamina_cost = 1, rarity = "normal", max_stack = 20, buy_price = 500, sell_price = 125 },
  preserve_turnip = { name_key = "ITEM_PRESERVE_TURNIP", description_key = "ITEM_PRESERVE_TURNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 140 },
  juice_turnip = { name_key = "ITEM_JUICE_TURNIP", description_key = "ITEM_JUICE_TURNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 135 },
  preserve_carrot = { name_key = "ITEM_PRESERVE_CARROT", description_key = "ITEM_PRESERVE_CARROT_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 180 },
  juice_carrot = { name_key = "ITEM_JUICE_CARROT", description_key = "ITEM_JUICE_CARROT_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 195 },
  preserve_pumpkin = { name_key = "ITEM_PRESERVE_PUMPKIN", description_key = "ITEM_PRESERVE_PUMPKIN_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 370 },
  juice_pumpkin = { name_key = "ITEM_JUICE_PUMPKIN", description_key = "ITEM_JUICE_PUMPKIN_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 480 },
  preserve_moonflower = { name_key = "ITEM_PRESERVE_MOONFLOWER", description_key = "ITEM_PRESERVE_MOONFLOWER_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 410 },
  juice_moonflower = { name_key = "ITEM_JUICE_MOONFLOWER", description_key = "ITEM_JUICE_MOONFLOWER_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 540 },
  preserve_glow_berry = { name_key = "ITEM_PRESERVE_GLOW_BERRY", description_key = "ITEM_PRESERVE_GLOW_BERRY_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 350 },
  juice_glow_berry = { name_key = "ITEM_JUICE_GLOW_BERRY", description_key = "ITEM_JUICE_GLOW_BERRY_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 450 },
  preserve_strawberry = { name_key = "ITEM_PRESERVE_STRAWBERRY", description_key = "ITEM_PRESERVE_STRAWBERRY_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 160 },
  juice_strawberry = { name_key = "ITEM_JUICE_STRAWBERRY", description_key = "ITEM_JUICE_STRAWBERRY_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 165 },
  preserve_sunflower = { name_key = "ITEM_PRESERVE_SUNFLOWER", description_key = "ITEM_PRESERVE_SUNFLOWER_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 190 },
  juice_sunflower = { name_key = "ITEM_JUICE_SUNFLOWER", description_key = "ITEM_JUICE_SUNFLOWER_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 210 },
  preserve_catnip = { name_key = "ITEM_PRESERVE_CATNIP", description_key = "ITEM_PRESERVE_CATNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 160 },
  juice_catnip = { name_key = "ITEM_JUICE_CATNIP", description_key = "ITEM_JUICE_CATNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 165 },
  preserve_snow_turnip = { name_key = "ITEM_PRESERVE_SNOW_TURNIP", description_key = "ITEM_PRESERVE_SNOW_TURNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 210 },
  juice_snow_turnip = { name_key = "ITEM_JUICE_SNOW_TURNIP", description_key = "ITEM_JUICE_SNOW_TURNIP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 240 },
  preserve_snowdrop = { name_key = "ITEM_PRESERVE_SNOWDROP", description_key = "ITEM_PRESERVE_SNOWDROP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 270 },
  juice_snowdrop = { name_key = "ITEM_JUICE_SNOWDROP", description_key = "ITEM_JUICE_SNOWDROP_DESC", category = "product", rarity = "normal", max_stack = 99, buy_price = 0, sell_price = 330 },
}
