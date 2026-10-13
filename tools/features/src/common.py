"""Shared constants of the feature content (the vocabulary the validator and the sim check the hand-owned Lua against).

Generation is RETIRED (review RV-P6): lua/**, localization/** are hand-owned since the one-time copy.  The generator's localisation registry (loc(), write_csvs(), round5()) is not kept.
The CD1 colours are in RARITY_UI (the generator would have re-written the legendary ring as the damage colour b3436b) and RARITY_EN follows CD19 (finds.csv: "Normal").
"""
from __future__ import annotations
import re
from collections import OrderedDict

RARITIES = ['normal', 'uncommon', 'rare', 'unique', 'legendary']
RANK = {r: i + 1 for i, r in enumerate(RARITIES)}
RARITY_DA = {'normal': 'Almindelig', 'uncommon': 'Ualmindelig', 'rare': 'Sjælden', 'unique': 'Unik', 'legendary': 'Legendarisk'}
RARITY_EN = {'normal': 'Normal', 'uncommon': 'Uncommon', 'rare': 'Rare', 'unique': 'Unique', 'legendary': 'Legendary'}
# UI colours (hex WITHOUT '#', because P10's lint reads '#' as the unsupported Lua length operator).  Same values as the wardrobe spike's
# RARITIES table; the gold ring stays reserved for focus/selected (style guide rule); legendary = the night tile with a Himmel ring, gold pips and a pale icon rim (CD1, RV-A2).
RARITY_UI = {
    'normal':    dict(fill='fbf5e6', ring='2b2340', label='4c4058'),
    'uncommon':  dict(fill='e3efd2', ring='6b9a3e', label='3f6b22'),
    'rare':      dict(fill='e2d8f4', ring='9b86d6', label='5d4fa3'),
    'unique':    dict(fill='f9e0e7', ring='e58fa6', label='7d2e59'),
    'legendary': dict(fill='2f3654', ring='a9d3e0', label='2b2340', pip='f2c14e', icon_rim='e4eff5'),
}

# world areas (map ids from PLAN 4.0) -> display
AREAS = OrderedDict([
    ('farm',          ('Trætoppen',     'Treetop Farm')),
    ('hyggebyen',         ('Hyggebyen',         'Hyggebyen')),
    ('skovkant',      ('Skovbrynet',    'The Forest Edge')),
    ('dybe_bregner',  ('Dybe Bregner',  'Deep Ferns')),
    ('svampelunden',  ('Svampelunden',  'Mushroom Grove')),
    ('krystalgrotten', ('Krystalgrotten', 'Crystal Cave')),
])
FOREST_AREAS = ['skovkant', 'dybe_bregner', 'svampelunden', 'krystalgrotten']
SEASONS = ['foraar', 'sommer', 'efteraar', 'vinter']

# NPC ids: PLAN 3.8 roster (+ the three shopkeeper/builder fairies this package adds)
NPCS_PLAN = ['mayor_lyra', 'baker_maja', 'merchant_pip', 'pippin_boegeknop', 'fairy_king', 'fairy_lily', 'smith_thorin', 'guard_oak',
             'farmer_rosa', 'fairy_wizard', 'cat_morfar_mis', 'penguin_postman']
NPCS_NEW = ['fairy_builder', 'fairy_furnisher', 'fairy_tailor']
NPCS = NPCS_PLAN + NPCS_NEW

# quests known to exist: repo lua/quests + PLAN 3.12 additions
QUESTS_REPO = ['animal_products', 'birthday_cake', 'cookie_delivery', 'crystal_cave', 'dark_forest_mining', 'enchanted_garden', 'fairy_friendship',
               'first_animal', 'fix_roof', 'flower_necklace', 'forest_patrol', 'intro_lottery', 'lost_cat', 'math_bakery_counts',
               'math_harvest_puzzle', 'math_wizard_quiz', 'night_flower', 'rare_mushroom_hunt', 'supply_run', 'sword_upgrade']
QUESTS_PLAN_NEW = ['moonstone_crown', 'sneglens_brev']
QUESTS_NEW = ['bogtraeet', 'snurresvampen', 'slotsdroemmen']          # moonstone_crown is PLAN-listed but written here (see SCHEMA)

# items that EXIST outside this package (repo lua/items or PLAN P12/P19 task lists) and that we reference
ITEMS_REPO = ['animal_treats', 'amethyst', 'baby_bunny', 'baby_calf', 'baby_chick', 'baby_duck', 'baby_fawn', 'baby_fox', 'baby_kitten', 'baby_lamb', 'baby_owl',
              'baby_puppy', 'barn_kit', 'brush', 'carrot', 'carrot_seeds', 'chicken_feed', 'cookie', 'coop_kit', 'crystal_shard', 'emerald',
              'fairy_dust', 'friendship_token', 'gold_ore', 'hoe_iron', 'hoe_wooden', 'iron_ore', 'lucky_clover', 'magic_scroll', 'mana_potion', 'milking_pail',
              'moonflower', 'moonflower_seeds', 'moss', 'pickaxe_iron', 'pickaxe_wooden', 'pumpkin', 'pumpkin_seeds', 'rare_mushroom', 'stone', 'teleport_stone',
              'turnip', 'turnip_seeds', 'watering_can_copper', 'watering_can_gold', 'wood', 'axe_wooden', 'sword_rusty', 'iron_sword']
ITEMS_PLAN = ['copper_ore', 'moonstone', 'wool', 'wild_flower', 'catnip_seeds', 'glow_mushroom', 'honey', 'flour', 'egg', 'iron_ingot', 'lantern_oil', 'health_tonic']

# shops and recipes referenced from elsewhere
SHOPS_PLAN = ['seed_shop', 'bakery', 'smithy', 'magic_store', 'animal_store']
SHOPS_NEW = ['furniture_shop', 'tailor_shop', 'builder_yard', 'flea_market']

# perk keys + caps (clothing + sets; home/hygge energy is capped separately by energy_total)
PERKS = ['speed', 'energy', 'luck', 'discount']
PERK_CAPS = dict(speed=0.15, energy=20, luck=0.20, discount=0.15)
ENERGY_TOTAL_CAP = 60
DISCOUNT_TOTAL_CAP = 0.20

SLOTS = ['hat', 'shirt', 'pants', 'dress', 'shoes', 'jewellery']
SLOT_DA = {'hat': 'Hat', 'shirt': 'Trøje', 'pants': 'Bukser', 'dress': 'Kjole', 'shoes': 'Sko', 'jewellery': 'Smykke'}
SLOT_EN = {'hat': 'Hat', 'shirt': 'Shirt', 'pants': 'Pants', 'dress': 'Dress', 'shoes': 'Shoes', 'jewellery': 'Jewellery'}
SUBSLOTS = {'circlet': ('Pandesmykke', 'Circlet'), 'necklace': ('Halskæde', 'Necklace'), 'bracelet': ('Armbånd', 'Bracelet'), 'earrings': ('Øreringe', 'Earrings')}

KEY_RE = re.compile(r'^[A-Z0-9_]+$')
