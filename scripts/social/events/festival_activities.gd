class_name FestivalActivities
extends RefCounted
## Pure contest arithmetic, shared by the live stage and acceptance probes.
const KINDS := ["contest","potluck","wish","feast","dance","market","scene"]

static func matches(item: String, definition: Dictionary, selector: String) -> bool:
	return GiftRules.selectors_of(item,definition).has(selector)

static func score(definition: Dictionary) -> float:
	return float(definition.get("sell_price",0))*(1.0+0.5*Rarity.pips(definition.get("rarity","normal")))

static func prize_value(prize: Dictionary, items: Dictionary) -> int:
	var value := maxi(0,int(prize.get("gold",0)))
	for item in LuaData.dict(prize.get("items",{})):
		var definition := LuaData.dict(items.get(item,{}))
		if definition.is_empty() or str(definition.get("rarity","normal")) in ["unique","legendary"] or int(prize.items[item]) < 1: return -1
		value += int(definition.get("sell_price",0))*int(prize.items[item])
	return value

static func cap(selector: String, items: Dictionary) -> int:
	var best := 0.0
	for id in items:
		var definition := LuaData.dict(items[id])
		if GiftRules.giftable(str(id),definition,int(definition.get("sell_price",0))).ok and matches(str(id),definition,selector): best = maxf(best,score(definition))
	var cheapest := 2147483647
	for id in items:
		var definition := LuaData.dict(items[id])
		if GiftRules.giftable(str(id),definition,int(definition.get("sell_price",0))).ok and matches(str(id),definition,selector) and score(definition)*1.15 >= best*0.85:
			cheapest = mini(cheapest,maxi(0,int(definition.get("sell_price",0))))
	return mini(400,2*cheapest) if cheapest < 2147483647 else 0

static func valid_prizes(selector: String, rewards: Dictionary, items: Dictionary) -> bool:
	var first := prize_value(LuaData.dict(rewards.get("first",{})),items)
	var second := prize_value(LuaData.dict(rewards.get("second",{})),items)
	var third := prize_value(LuaData.dict(rewards.get("third",{})),items)
	return first >= 0 and first <= cap(selector,items) and second >= 0 and second <= first*0.7 and third >= 0 and third <= first*0.4

static func contest(item: String, selector: String, rewards: Dictionary, items: Dictionary, seed: int, festival: String, year: int) -> Dictionary:
	var definition := LuaData.dict(items.get(item,{}))
	if definition.is_empty() or not GiftRules.giftable(item,definition,int(definition.get("sell_price",0))).ok or not matches(item,definition,selector): return {"ok":false,"reason":"item"}
	if not valid_prizes(selector,rewards,items): return {"ok":false,"reason":"prize_cap"}
	var best := 0.0
	for id in items:
		if GiftRules.giftable(str(id),LuaData.dict(items[id]),int(items[id].get("sell_price",0))).ok and matches(str(id),LuaData.dict(items[id]),selector): best = maxf(best,score(items[id]))
	var mine := score(definition)*(0.85+0.3*SocialRng.roll(seed,[festival,year,"contest","player"]))
	var rank := 4
	var bars: Array[float] = []
	for index in 3:
		var bar: float = best*[0.5,0.75,1.0][index]*(0.85+0.3*SocialRng.roll(seed,[festival,year,"contest","bar",index]))
		bars.append(bar)
		if mine >= bar: rank -= 1
	var prize: Dictionary = LuaData.dict(rewards.get(["first","second","third"][rank-1],{})) if rank <= 3 else {}
	return {"ok":true,"rank":rank,"score":mine,"bars":bars,"prize":prize.duplicate(true)}

static func options(selector: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in GiftFlow._stock():
		var id := str(row.id)
		var definition := ItemKinds.def(id)
		if matches(id,definition,selector) and GiftRules.giftable(id,definition,int(row.value)).ok and GiftFlow.protection(id,definition) == "":
			var entry := row.duplicate()
			entry["confirm"] = false
			out.append(entry)
	return out
