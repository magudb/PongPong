"""Constants and design tables of the clothing catalogue that the content validator imports (tools/features/validate/validate.py, rules C8 / C9c).

Generation is RETIRED (review RV-P6): lua/items/clothing.lua and localization/wardrobe.csv are hand-owned since the one-time copy, so the 96 `C(...)` catalogue rows of the original
generator source are NOT kept here (they would be a second source of truth that silently drifts from the Lua).  What stays is the vocabulary the catalogue is checked against:

  EXISTING_DESIGNS   garment designs that exist in the wardrobe art (art spike tools/characters/wardrobe_garments.py GARMENTS, later tools/art/features/wardrobe) -> art slot
  REQUESTED_DESIGNS  designs the catalogue asks the art pipeline to add: design -> (art slot, fallback design that exists today, brief da, brief en); mirrors specs/wardrobe_design_requests.json
  COLOR_IDS          descriptive colour ids for `art.colors` (style-guide palette first)
  PATTERN_OF         design -> material / pattern of the baked garment
  SLOT_OF_DESIGN, SLOT_F
"""
from __future__ import annotations

# art designs that exist in spike_wardrobe/tools/characters/wardrobe_garments.py (GARMENTS dict) -> slot of the art
EXISTING_DESIGNS = {
    'shirt_linen': 'shirt', 'shirt_knit': 'shirt', 'pants_trousers': 'pants', 'pants_dungarees': 'pants', 'dress_sun': 'dress', 'dress_gown': 'dress',
    'shoes_boots': 'shoes', 'shoes_slippers': 'shoes', 'hat_straw': 'hat', 'hat_cap': 'hat', 'hat_wizard': 'hat', 'circlet_crown': 'circlet',
    'neck_pendant': 'necklace', 'wrist_bangles': 'bracelet', 'ears_hoops': 'earrings'}
# designs this catalogue asks the art pipeline to add: design -> (art slot, fallback design, brief da, brief en)
REQUESTED_DESIGNS = {
    'hat_hood':        ('hat', 'hat_cap', 'Blød hætte, der falder om nakken', 'Soft hood that drapes over the neck'),
    'hat_acorn':       ('hat', 'hat_cap', 'Hue formet som en agernskål med lille stilk', 'Cap shaped like an acorn cup with a small stalk'),
    'hat_chef':        ('hat', 'hat_cap', 'Høj, buet bagerhue', 'Tall, puffed baker cap'),
    'hat_mushroom':    ('hat', 'hat_straw', 'Svampehat med prikker og lille hage', 'Mushroom-cap hat with spots and a small chin strap'),
    'hat_cat':         ('hat', 'hat_cap', 'Blød lue med to spidse kattelyd-ører', 'Soft beanie with two pointed cat ears'),
    'shirt_smock':     ('shirt', 'shirt_linen', 'Rummelig kittel med brede ærmer og snøre i halsen', 'Roomy smock with wide sleeves and a drawstring neck'),
    'shirt_vest':      ('shirt', 'shirt_linen', 'Ærmeløs vest med lommer over hørskjorte', 'Sleeveless pocket vest over a linen shirt'),
    'pants_shorts':    ('pants', 'pants_trousers', 'Korte bukser med omslag', 'Short trousers with turn-ups'),
    'pants_breeches':  ('pants', 'pants_trousers', 'Knickers, der slutter under knæet', 'Breeches ending below the knee'),
    'dress_pinafore':  ('dress', 'dress_sun', 'Forklædekjole med lommer og brede stropper', 'Pinafore dress with pockets and wide straps'),
    'shoes_clogs':     ('shoes', 'shoes_boots', 'Træsko med let opadbøjet snude', 'Wooden clogs with a slightly upturned toe'),
    'shoes_wellies':   ('shoes', 'shoes_boots', 'Høje gummistøvler med bred kant', 'Tall rubber boots with a wide cuff'),
    'circlet_flowers': ('circlet', 'circlet_crown', 'Krans af blomster eller blade', 'Wreath of flowers or leaves'),
    'necklace_beads':  ('necklace', 'neck_pendant', 'Snor med perler', 'String of beads'),
    'bracelet_braid':  ('bracelet', 'wrist_bangles', 'Flettet armbånd', 'Braided bracelet'),
}
# descriptive colour ids (style-guide palette first) used for `art.colors`; the garment shader only needs the hex palette, the ids are for UI swatches / search
COLOR_IDS = {
    'F4E6C4': 'pergament', '6B9A3E': 'mosgroen', 'E8B04A': 'honning', '7A4E2D': 'bark', 'A9D3E0': 'himmel', '9B86D6': 'lavendel', 'E58FA6': 'rosenblad', 'E3C372': 'fe_guld',
    'FBF5E6': 'kridt', '2B2340': 'blaek', '1C2138': 'natblaa', '2F4A3F': 'skyggemos', '6FD6C4': 'svampelys', 'F2C14E': 'ugleoeje', 'B3436B': 'tornebaer',
    '5B7DA8': 'denim', 'C0C6D0': 'soelv', 'E3C07A': 'straa', 'F3EAD3': 'hoer', 'D98A5A': 'kobber', '7FC8A5': 'mynte', 'A9744A': 'laeder', '4A3228': 'moerkt_laeder',
    'E9C06B': 'guld', 'C9B58E': 'kaki', '8C6B3F': 'tweed', 'B58A52': 'agern', 'C9A15E': 'trae', 'D9BE78': 'hvede', 'EBD79E': 'straa_lys', 'E9DCC0': 'uld', '8DB86A': 'eng',
    'D86A8E': 'pink', '4C58A0': 'kongeblaa', 'C9D4EE': 'maane', 'FFFFFF': 'hvid'}
PATTERN_OF = {   # design -> material / pattern of the baked garment (descriptive)
    'hat_straw': 'straw', 'hat_cap': 'wool', 'hat_wizard': 'felt', 'hat_hood': 'wool', 'hat_acorn': 'felt', 'hat_chef': 'linen', 'hat_mushroom': 'felt', 'hat_cat': 'knit',
    'shirt_linen': 'linen', 'shirt_knit': 'knit', 'shirt_smock': 'linen', 'shirt_vest': 'wool', 'pants_trousers': 'twill', 'pants_dungarees': 'canvas', 'pants_shorts': 'twill',
    'pants_breeches': 'tweed', 'dress_sun': 'cotton', 'dress_gown': 'silk', 'dress_pinafore': 'cotton', 'shoes_boots': 'leather', 'shoes_slippers': 'wool', 'shoes_clogs': 'wood',
    'shoes_wellies': 'rubber', 'circlet_crown': 'metal', 'circlet_flowers': 'plant', 'neck_pendant': 'metal', 'necklace_beads': 'beads', 'wrist_bangles': 'metal',
    'bracelet_braid': 'braid', 'ears_hoops': 'metal'}
SLOT_OF_DESIGN = dict(EXISTING_DESIGNS, **{k: v[0] for k, v in REQUESTED_DESIGNS.items()})
SLOT_F = {'hat': 1.0, 'shirt': 1.0, 'pants': 0.9, 'dress': 1.4, 'shoes': 0.9, 'circlet': 1.6, 'necklace': 1.3, 'bracelet': 1.0, 'earrings': 1.0}
