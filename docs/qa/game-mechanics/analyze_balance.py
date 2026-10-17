#!/usr/bin/env python3
"""Recompute review tables from the Godot-exported runtime catalog; standard library only."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
data = json.loads((HERE / "runtime-data.json").read_text())
items, offers = data["items"], data["prices"]
sell = data["sell_values"]


def minimum_buy(item, include_gated=True):
    rows = [
        (row["buy"], shop)
        for shop, row in offers.get(item, {}).items()
        if row["buy"] > 0
        and (include_gated or (shop != "greenhouse_seeds" and not shop.startswith("fest_")))
    ]
    return min(rows) if rows else (None, None)


crops = []
fertilizer = minimum_buy("fertilizer", False)[0]
for crop, config in data["crops"].items():
    seed_item = next(
        item for item, definition in items.items()
        if definition.get("category") == "seed" and definition.get("crop_id") == crop
    )
    seed_price, shop = minimum_buy(seed_item, False)
    gated = seed_price is None
    if gated:
        seed_price, shop = minimum_buy(seed_item)
    days = int(config["stages"] * config["days_per_stage"])
    regrow = int(config.get("regrow_days", 0))
    # Plant on season day 1, harvest through day 28: 27 overnight growth ticks.
    harvests = (1 + (27 - days) // regrow if regrow else 27 // days) if days <= 27 else 0
    seeds = 1 if regrow else harvests
    crop_sell = sell[crop]
    crops.append({
        "crop": crop, "seasons": config["seasons"], "growth_days": days,
        "regrow_days": regrow, "seed_price": seed_price, "source": shop,
        "greenhouse_required_for_seed": gated, "sell": crop_sell,
        "harvests_by_day_28": harvests,
        "raw_net_by_day_28": harvests * crop_sell - seeds * seed_price,
        "fertilized_net_by_day_28": harvests * (2 * crop_sell - fertilizer) - seeds * seed_price,
        "jar_added_value_per_machine_day": (sell["preserve_" + crop] - crop_sell) / 2,
        "keg_added_value_per_machine_day": (sell["juice_" + crop] - crop_sell) / 3,
    })

intervals = {"daily": 1, "every_2_days": 2, "every_3_days": 3}
animals = []
for species, config in data["husbandry"]["species"].items():
    interval = intervals.get(config["product_interval"])
    if interval is None:
        continue  # Cats/dogs generate bond keepsakes, not periodic income.
    low, high = config["product_amount"]
    animals.append({
        "species": species, "mature_days": config["grow_days"],
        "building": config["building"], "product": config["product"],
        "base_units_per_day": (low + high) / 2 / interval,
        "happy_units_per_day": ((low + high) / 2 + 1) / interval,
        "happy_gross_gold_per_day": (((low + high) / 2 + 1) / interval) * sell[config["product"]],
    })

resell, craft_loops = [], []
for item in items:
    buy, shop = minimum_buy(item)
    if buy is not None and sell[item] > buy:
        resell.append({"item": item, "buy": buy, "sell": sell[item], "shop": shop})
for recipe_id, recipe in data["recipes"].items():
    ingredients = recipe.get("ingredients", {})
    if not ingredients or any(minimum_buy(item)[0] is None for item in ingredients):
        continue
    cost = sum(minimum_buy(item)[0] * amount for item, amount in ingredients.items())
    output = recipe.get("output", {})
    revenue = sell.get(output.get("item"), 0) * output.get("amount", 1)
    if revenue > cost:
        craft_loops.append({"recipe": recipe_id, "cost": cost, "revenue": revenue})

result = {
    "base_commit": data["base_commit"],
    "assumptions": [
        "Day-1 runtime prices, no discount perks; ordinary shops preferred for seeds.",
        "Plant day 1; water daily in the correct window; harvest/replant immediately through day 28.",
        "One base crop; no race bonus. Fertilized scenario reapplies 15g fertilizer for every harvest.",
        "Crop net excludes labour, tools, travel, limited shop stock, and unsold carryover plants.",
        "Machines continuously supplied; added value deducts raw crop sale value, not seed cost twice.",
        "Animal figures are mature steady-state gross averages, collected immediately at happiness >=80.",
        "Animal figures exclude feed, building, animal purchase, and maturity; they are not net ROI.",
        "Arbitrage scan covers current catalog offers, deterministic single-output crafts, no random Hobbit bonus.",
        "Offers across seasonal/festival/greenhouse shops do not imply immediate day-1 access.",
    ],
    "crops": crops, "animals": animals,
    "direct_resell_candidates": resell, "buy_craft_sell_candidates": craft_loops,
}
(HERE / "balance.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
print(f"Analyzed {len(items)} items, {len(data['shops'])} shops, {len(data['recipes'])} recipes, "
      f"{len(crops)} crops and {len(animals)} periodic animal products.")
print(f"Base-price resale candidates: {len(resell)}; deterministic buy/craft/sell candidates: {len(craft_loops)}.")
