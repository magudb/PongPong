-- lua/buildings/ghostfam.lua - the ONE building of the ghost family (GF-data; registry `buildings`, KEY = building id: a duplicate id across files is a claim error, so T-towns-core's decor row `gaestehytten`
-- of lua/buildings/traetoppen.lua is REMOVED by amendment AGF4 and this file defines the id).  Hut 11 of the city sketch = V3's building id h12 (data/traetoppen/traetoppen.json, door (693.8, 1043.7) sketch px, level F).
-- name_key stays BLD_GAESTEHYTTEN ("Gaestehytten", towns.csv): the sign reads 'Gaestehytten - aabent 17-01'; the shop's own name is SHOP_LANTERN_HOUSE.
-- hours: GAME HOURS on the 6..26 axis (CLOCK_26): open 17 = 17:00, close 25 = 01:00 of the SAME game day (the weekday stays until the day rolls at 26 = 02:00); closed = { 2 } = Wednesday (Familieaften, the whole
-- evening and the night after it).  A close above 24 is a plain interval (open <= hour < close), NOT a wrap (T-towns-core amendment: Hours accepts close <= 26).
kind = "registry"
registry = "buildings"

buildings = {
  gaestehytten = {
    area = "traetoppen", kind = "shop", name_key = "BLD_GAESTEHYTTEN",
    interior = "int_gaestehytten", size = "S",
    shop = "lantern_house",
    keeper = "ghostfam_gnist",
    post = "int_gaestehytten.counter",
    hours = { open = 17, close = 25, closed = { 2 } },
    wave = "core",
  },
}
