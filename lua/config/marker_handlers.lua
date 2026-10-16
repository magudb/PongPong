-- config/marker_handlers.lua  (package F4-loot-shops: the ONLY owner of this file; every other package adds ROWS through its order's amendment list and never edits it)
-- Marker type -> handler script. IsoArea.marker_registry() merges this table OVER its built-in one (GameData.marker_handlers() reads it). A handler script needs ONE entry point:
--   static func create_marker(params, pos, cell, area) -> Node      or an instance  func setup_marker(params, pos, cell, area)  on a Node script
-- the node is adopted into area.objects at the cell and obeys `when=`. A script that does not exist yet, or has no entry point, is skipped silently (counted in area.skipped_markers),
-- so a row can be here before its package has landed. Rows are grouped by the package that owns the script.
-- Not here on purpose: `greenhouse_slot` (a data marker read with find_markers until N07), the city's own interactables seed_basket kiki_cache rejsestolpe lift climb (V4's builder
-- instantiates them from the city's own data; the town ROOMS place bath and board from their room JSON, which is why those two have rows below), and the built-in types
-- spawn warp sign bed quest_spot light growth.
kind = "config"

config = {
  marker_handlers = {
    -- F4 (this package): loot
    chest = "res://scripts/world2d/loot_chest_2d.gd",
    dig_spot = "res://scripts/world2d/dig_spot_2d.gd",
    unique_spot = "res://scripts/world2d/unique_spot_2d.gd",
    -- F6 (home world)
    home = "res://scripts/home/home_exterior_2d.gd",
    tent = "res://scripts/home/tent_2d.gd",
    -- D2 (dungeon floors)
    runestone = "res://scripts/dungeon/markers/runestone_2d.gd",
    -- V8 (forest look)
    forest_dress = "res://scripts/forest_look/forest_dress.gd",
    hulen_keeper = "res://scripts/forest_look/hulen_keeper.gd",
    -- V6 (city life)
    mailbox = "res://scripts/traetoppen/life/post_box_2d.gd",
    seed_basket = "res://scripts/traetoppen/life/seed_basket_2d.gd",
    kiki_cache = "res://scripts/traetoppen/life/crown_cache_2d.gd",
    rejsestolpe = "res://scripts/traetoppen/life/rejsestolpe_2d.gd",
    bath = "res://scripts/traetoppen/life/bath_tub_2d.gd",
    board = "res://scripts/traetoppen/life/notice_board_2d.gd",
    -- N02 / N05 (the farm steading); field_expansion replaces the lazy farm_view.gd entry of IsoArea
    shipping_bin = "res://scripts/farm/steading/objects/shipping_bin_2d.gd",
    tool_shed = "res://scripts/farm/steading/objects/tool_shed_2d.gd",
    field_expansion = "res://scripts/farm/steading/objects/field_expansion_2d.gd",
    underdeck = "res://scripts/farm/steading/objects/underdeck_2d.gd",
    ambient_fx = "res://scripts/farm/steading/objects/ambient_fx_2d.gd",
    dress = "res://scripts/farm/steading/dress/dress_2d.gd",
    -- T-director (the towns): ONE script serves the three types
    town = "res://scripts/towns/town_marker.gd",
    door = "res://scripts/towns/town_marker.gd",
    post = "res://scripts/towns/town_marker.gd",
  },
}
