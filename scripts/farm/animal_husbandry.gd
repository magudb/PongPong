extends Node
## Farm animal husbandry: feeding, happiness, products, care, buildings.

signal animal_added(animal_id: StringName, species: StringName)
signal animal_fed(animal_id: StringName, food_id: StringName)
signal animal_happy(animal_id: StringName, happiness: float)
signal animal_product_collected(animal_id: StringName, product_id: StringName, amount: int)
signal animal_bonded(animal_id: StringName, bond_level: int)

enum Species { CHICKEN, RABBIT, DUCK, CAT, DOG, SHEEP, COW, DEER, FOX, OWL }
enum ProductType { DAILY, EVERY_2_DAYS, EVERY_3_DAYS, ON_BOND }

const SAVE_VERSION := 2
const PRODUCT_DAYS := {ProductType.DAILY: 1, ProductType.EVERY_2_DAYS: 2, ProductType.EVERY_3_DAYS: 3}

const SPECIES_DATA := {
	"chicken": {
		"name_key": "ITEM_BABY_CHICK",
		"species": Species.CHICKEN,
		"product": "egg",
		"product_amount": [1, 2],
		"product_interval": ProductType.DAILY,
		"max_happiness": 100,
		"happiness_decay_per_day": 8.0,
		"feed_types": ["chicken_feed", "animal_treats"],
		"favorite_feed": "chicken_feed",
		"favorite_feed_bonus": 15.0,
		"building": "coop",
		"base_value": 80,
		"grow_days": 3,
	},
	"rabbit": {
		"name_key": "ITEM_BABY_BUNNY",
		"species": Species.RABBIT,
		"product": "wool",
		"product_amount": [1, 1],
		"product_interval": ProductType.EVERY_2_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 6.0,
		"feed_types": ["animal_treats", "carrot"],
		"favorite_feed": "carrot",
		"favorite_feed_bonus": 20.0,
		"building": "coop",
		"base_value": 95,
		"grow_days": 2,
	},
	"duck": {
		"name_key": "ITEM_BABY_DUCK",
		"species": Species.DUCK,
		"product": "duck_egg",
		"product_amount": [1, 1],
		"product_interval": ProductType.EVERY_2_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 7.0,
		"feed_types": ["chicken_feed", "animal_treats"],
		"favorite_feed": "chicken_feed",
		"favorite_feed_bonus": 15.0,
		"building": "coop",
		"base_value": 110,
		"grow_days": 3,
	},
	"cat": {
		"name_key": "ITEM_BABY_KITTEN",
		"species": Species.CAT,
		"product": "friendship_token",
		"product_amount": [1, 1],
		"product_interval": ProductType.ON_BOND,
		"max_happiness": 100,
		"happiness_decay_per_day": 4.0,
		"feed_types": ["animal_treats", "fish"],
		"favorite_feed": "fish",
		"favorite_feed_bonus": 25.0,
		"building": "house",
		"base_value": 180,
		"grow_days": 5,
	},
	"dog": {
		"name_key": "ITEM_BABY_PUPPY",
		"species": Species.DOG,
		"product": "friendship_token",
		"product_amount": [1, 1],
		"product_interval": ProductType.ON_BOND,
		"max_happiness": 100,
		"happiness_decay_per_day": 4.0,
		"feed_types": ["animal_treats", "cookie"],
		"favorite_feed": "cookie",
		"favorite_feed_bonus": 25.0,
		"building": "house",
		"base_value": 180,
		"grow_days": 5,
	},
	"sheep": {
		"name_key": "ITEM_BABY_LAMB",
		"species": Species.SHEEP,
		"product": "wool",
		"product_amount": [1, 2],
		"product_interval": ProductType.EVERY_3_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 6.0,
		"feed_types": ["animal_treats", "turnip"],
		"favorite_feed": "turnip",
		"favorite_feed_bonus": 20.0,
		"building": "barn",
		"base_value": 210,
		"grow_days": 6,
	},
	"cow": {
		"name_key": "ITEM_BABY_CALF",
		"species": Species.COW,
		"product": "milk",
		"product_amount": [1, 2],
		"product_interval": ProductType.DAILY,
		"max_happiness": 100,
		"happiness_decay_per_day": 7.0,
		"feed_types": ["animal_treats", "turnip", "carrot"],
		"favorite_feed": "carrot",
		"favorite_feed_bonus": 20.0,
		"building": "barn",
		"base_value": 260,
		"grow_days": 8,
	},
	"deer": {
		"name_key": "ITEM_BABY_FAWN",
		"species": Species.DEER,
		"product": "magic_herb",
		"product_amount": [1, 1],
		"product_interval": ProductType.EVERY_2_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 5.0,
		"feed_types": ["animal_treats", "glow_berry"],
		"favorite_feed": "glow_berry",
		"favorite_feed_bonus": 30.0,
		"building": "barn",
		"base_value": 310,
		"grow_days": 7,
	},
	"fox": {
		"name_key": "ITEM_BABY_FOX",
		"species": Species.FOX,
		"product": "lucky_fur",
		"product_amount": [1, 1],
		"product_interval": ProductType.EVERY_3_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 5.0,
		"feed_types": ["animal_treats", "cookie", "fish"],
		"favorite_feed": "fish",
		"favorite_feed_bonus": 25.0,
		"building": "house",
		"base_value": 380,
		"grow_days": 6,
	},
	"owl": {
		"name_key": "ITEM_BABY_OWL",
		"species": Species.OWL,
		"product": "wisdom_feather",
		"product_amount": [1, 1],
		"product_interval": ProductType.EVERY_3_DAYS,
		"max_happiness": 100,
		"happiness_decay_per_day": 4.0,
		"feed_types": ["animal_treats", "rare_mushroom"],
		"favorite_feed": "rare_mushroom",
		"favorite_feed_bonus": 30.0,
		"building": "house",
		"base_value": 410,
		"grow_days": 8,
	},
}

const BUILDINGS := {
	"coop": {
		"name_key": "BUILDING_COOP",
		"capacity": 4,
		"build_cost": {"wood": 20, "stone": 10, "gold": 500},
		"build_days": 2,
	},
	"barn": {
		"name_key": "BUILDING_BARN",
		"capacity": 6,
		"build_cost": {"wood": 40, "stone": 25, "gold": 1200},
		"build_days": 4,
	},
	"house": {
		"name_key": "BUILDING_HOUSE",
		"capacity": 3,
		"build_cost": {"wood": 15, "stone": 8, "gold": 350},
		"build_days": 1,
	},
}

var animals: Dictionary = {}  # animal_id -> AnimalData
var buildings: Dictionary = {}  # building_id -> BuildingData
var _animal_counter: int = 0


class AnimalData:
	var id: StringName
	var species: StringName
	var name: String = ""
	var happiness: float = 50.0
	var hunger: float = 50.0
	var bond_level: int = 0
	var bond_xp: float = 0.0
	var age_days: int = 0
	var is_baby: bool = true
	var building_id: StringName = &""
	var last_fed_day: int = 0
	var last_product_day: int = 0
	var products_ready: int = 0

	func to_dict() -> Dictionary:
		return {
			"id": id, "species": species, "name": name,
			"happiness": happiness, "hunger": hunger,
			"bond_level": bond_level, "bond_xp": bond_xp,
			"age_days": age_days, "is_baby": is_baby,
			"building_id": building_id,
			"last_fed_day": last_fed_day,
			"last_product_day": last_product_day,
			"products_ready": products_ready,
		}

	static func from_dict(d: Dictionary) -> AnimalData:
		var a := AnimalData.new()
		a.id = d.get("id", &"")
		a.species = d.get("species", &"")
		a.name = d.get("name", "")
		a.happiness = d.get("happiness", 50.0)
		a.hunger = d.get("hunger", 50.0)
		a.bond_level = d.get("bond_level", 0)
		a.bond_xp = d.get("bond_xp", 0.0)
		a.age_days = d.get("age_days", 0)
		a.is_baby = d.get("is_baby", true)
		a.building_id = d.get("building_id", &"")
		a.last_fed_day = d.get("last_fed_day", 0)
		a.last_product_day = d.get("last_product_day", 0)
		a.products_ready = d.get("products_ready", 0)
		return a


class BuildingData:
	var id: StringName
	var building_type: StringName
	var animals_inside: Array[StringName] = []
	var built_day: int = 0
	var is_built: bool = false

	func to_dict() -> Dictionary:
		return {
			"id": id, "building_type": building_type,
			"animals_inside": animals_inside.duplicate(),
			"built_day": built_day, "is_built": is_built,
		}

	static func from_dict(d: Dictionary) -> BuildingData:
		var b := BuildingData.new()
		b.id = d.get("id", &"")
		b.building_type = d.get("building_type", &"")
		b.animals_inside.assign(d.get("animals_inside", []))
		b.built_day = d.get("built_day", 0)
		b.is_built = d.get("is_built", false)
		return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(reset)


func reset() -> void:
	animals.clear()
	buildings.clear()
	_animal_counter = 0


# --- Animal management ---

func adopt_animal(item_id: StringName) -> bool:
	# Map item to species
	var species := _item_to_species(item_id)
	if species == &"":
		return false

	# Check for space
	if not _has_space_for(species):
		EventBus.notification_posted.emit(
			tr("NOTIF_NO_SPACE_TITLE"),
			tr("NOTIF_NO_SPACE_MSG"),
			"animal"
		)
		return false

	# Remove item
	if not EconomyManager.remove_item(item_id, 1):
		return false

	_animal_counter += 1
	var animal := AnimalData.new()
	animal.id = StringName("animal_%d" % _animal_counter)
	animal.species = species
	animal.name = _random_animal_name()
	animal.age_days = 0
	animal.is_baby = true
	animal.happiness = 60.0
	animal.hunger = 70.0
	animal.last_product_day = GameManager.total_day()

	# Place in building
	var building_id := _find_building_with_space(species)
	animal.building_id = building_id
	if building_id != &"":
		(buildings[building_id] as BuildingData).animals_inside.append(animal.id)

	animals[animal.id] = animal
	animal_added.emit(animal.id, species)
	EventBus.animal_adopted.emit(animal.id, species)

	EventBus.notification_posted.emit(
		tr("NOTIF_ANIMAL_ADOPTED_TITLE"),
		"%s (%s)" % [animal.name, tr(SPECIES_DATA[str(species)]["name_key"])],
		"animal"
	)
	return true


func feed_animal(animal_id: StringName, food_id: StringName) -> bool:
	if not animals.has(animal_id):
		return false
	var animal: AnimalData = animals[animal_id]
	var spec: Dictionary = SPECIES_DATA[str(animal.species)]

	if not EconomyManager.has_item(food_id, 1):
		return false

	# Check if animal accepts this food
	var feed_types: Array = spec["feed_types"]
	if str(food_id) not in feed_types and str(food_id) != "animal_treats":
		EventBus.notification_posted.emit(
			tr("NOTIF_WRONG_FOOD_TITLE"),
			tr("NOTIF_WRONG_FOOD_MSG"),
			"animal"
		)
		return false

	EconomyManager.remove_item(food_id, 1)

	var hunger_restore := 30.0
	var happiness_boost := 5.0

	# Favorite food bonus
	if str(food_id) == spec["favorite_feed"]:
		happiness_boost = spec["favorite_feed_bonus"]
		EventBus.notification_posted.emit(
			tr("NOTIF_FAVORITE_FOOD_TITLE"),
			tr("NOTIF_FAVORITE_FOOD_MSG") % animal.name,
			"animal"
		)

	animal.hunger = minf(animal.hunger + hunger_restore, 100.0)
	animal.happiness = minf(animal.happiness + happiness_boost, spec["max_happiness"])
	animal.last_fed_day = GameManager.total_day()

	_add_bond_xp(animal, 5.0)
	animal_fed.emit(animal_id, food_id)
	animal_happy.emit(animal_id, animal.happiness)
	EventBus.animal_fed.emit(animal_id, food_id)
	return true


func brush_animal(animal_id: StringName) -> bool:
	if not animals.has(animal_id):
		return false
	var animal: AnimalData = animals[animal_id]

	if not EconomyManager.has_item(&"brush", 1):
		EventBus.notification_posted.emit(
			tr("NOTIF_NO_BRUSH_TITLE"),
			tr("NOTIF_NO_BRUSH_MSG"),
			"animal"
		)
		return false

	animal.happiness = minf(animal.happiness + 10.0, 100.0)
	_add_bond_xp(animal, 8.0)
	animal_happy.emit(animal_id, animal.happiness)

	EventBus.notification_posted.emit(
		tr("NOTIF_ANIMAL_BRUSHED_TITLE"),
		"%s %s" % [animal.name, tr("NOTIF_ANIMAL_BRUSHED_MSG")],
		"animal"
	)
	return true


func play_with_animal(animal_id: StringName) -> bool:
	if not animals.has(animal_id):
		return false
	var animal: AnimalData = animals[animal_id]

	animal.happiness = minf(animal.happiness + 15.0, 100.0)
	animal.hunger = maxf(animal.hunger - 5.0, 0.0)
	_add_bond_xp(animal, 12.0)
	animal_happy.emit(animal_id, animal.happiness)

	EventBus.notification_posted.emit(
		tr("NOTIF_ANIMAL_PLAYED_TITLE"),
		"%s %s" % [animal.name, tr("NOTIF_ANIMAL_PLAYED_MSG")],
		"animal"
	)
	return true


func collect_product(animal_id: StringName) -> int:
	if not animals.has(animal_id):
		return 0
	var animal: AnimalData = animals[animal_id]
	var spec: Dictionary = SPECIES_DATA[str(animal.species)]

	if animal.products_ready <= 0:
		return 0

	var product_id: StringName = StringName(spec["product"])
	var amount: int = animal.products_ready

	# Happiness modifier
	if animal.happiness >= 80.0:
		amount += 1

	if not EconomyManager.add_item(product_id, amount):
		return 0
	animal.products_ready = 0
	animal.last_product_day = GameManager.total_day()

	animal_product_collected.emit(animal_id, product_id, amount)
	EventBus.animal_product_collected.emit(animal_id, product_id, amount)

	EventBus.notification_posted.emit(
		tr("NOTIF_PRODUCT_COLLECTED_TITLE"),
		"%s x%d" % [tr("ITEM_%s" % str(product_id).to_upper()), amount],
		"animal"
	)
	return amount


# --- Buildings ---

func build_building(building_type: StringName) -> bool:
	var spec: Dictionary = BUILDINGS.get(str(building_type), {})
	if spec.is_empty():
		return false

	# Check cost
	var cost: Dictionary = spec.get("build_cost", {})
	for item_id in cost:
		if item_id == "gold":
			if not EconomyManager.can_afford(cost[item_id]):
				_notify_cannot_afford()
				return false
		else:
			if not EconomyManager.has_item(StringName(item_id), cost[item_id]):
				EventBus.notification_posted.emit(
					tr("NOTIF_MISSING_MATERIALS_TITLE"),
					tr("NOTIF_MISSING_MATERIALS_MSG"),
					"build"
				)
				return false

	# Pay cost
	for item_id in cost:
		if item_id == "gold":
			EconomyManager.spend_gold(cost[item_id])
		else:
			EconomyManager.remove_item(StringName(item_id), cost[item_id])

	_animal_counter += 1
	var building := BuildingData.new()
	building.id = StringName("%s_%d" % [building_type, _animal_counter])
	building.building_type = building_type
	building.built_day = GameManager.total_day()
	building.is_built = true
	buildings[building.id] = building
	EventBus.building_built.emit(building.id, building_type)

	EventBus.notification_posted.emit(
		tr("NOTIF_BUILDING_BUILT_TITLE"),
		tr(spec["name_key"]),
		"build"
	)
	return true


func has_building(building_type: StringName) -> bool:
	for bid in buildings:
		var b: BuildingData = buildings[bid]
		if b.building_type == building_type and b.is_built:
			return true
	return false


func get_building_capacity(building_type: StringName) -> int:
	var total := 0
	for bid in buildings:
		var b: BuildingData = buildings[bid]
		if b.building_type == building_type and b.is_built:
			total += BUILDINGS[str(building_type)]["capacity"]
	return total


func get_animals_in_building(building_id: StringName) -> Array:
	if not buildings.has(building_id):
		return []
	var out: Array = []
	for aid in (buildings[building_id] as BuildingData).animals_inside:
		if animals.has(aid):
			out.append(animals[aid])
	return out


# --- Daily updates ---

func _on_day_started(_day: int, _season: StringName) -> void:
	var today := GameManager.total_day()
	for aid in animals:
		var animal: AnimalData = animals[aid]
		var spec: Dictionary = SPECIES_DATA[str(animal.species)]

		# Age
		animal.age_days += 1
		if animal.is_baby and animal.age_days >= spec["grow_days"]:
			animal.is_baby = false

		# Hunger decay
		animal.hunger = maxf(animal.hunger - 10.0, 0.0)

		# Happiness decay (faster if hungry)
		var decay: float = spec["happiness_decay_per_day"]
		if animal.hunger < 30.0:
			decay *= 1.5
		animal.happiness = maxf(animal.happiness - decay, 0.0)

		# Product generation
		if not animal.is_baby and animal.happiness >= 30.0 and animal.products_ready == 0:
			var interval: int = int(PRODUCT_DAYS.get(spec["product_interval"], 0))
			if interval > 0 and today - animal.last_product_day >= interval:
				animal.products_ready = randi_range(int(spec["product_amount"][0]), int(spec["product_amount"][1]))
				animal.last_product_day = today

		# Bond level up check
		_check_bond_level(animal)


func _add_bond_xp(animal: AnimalData, amount: float) -> void:
	animal.bond_xp += amount
	_check_bond_level(animal)


func _check_bond_level(animal: AnimalData) -> void:
	var xp_needed: float = (animal.bond_level + 1) * 50.0
	if animal.bond_xp >= xp_needed:
		animal.bond_xp -= xp_needed
		animal.bond_level += 1
		var spec: Dictionary = SPECIES_DATA[str(animal.species)]
		if int(spec["product_interval"]) == ProductType.ON_BOND:
			animal.products_ready += int(spec["product_amount"][1])
		animal_bonded.emit(animal.id, animal.bond_level)

		EventBus.notification_posted.emit(
			tr("NOTIF_BOND_LEVEL_TITLE"),
			tr("NOTIF_BOND_LEVEL_MSG") % [animal.name, animal.bond_level],
			"animal"
		)


# --- Helpers ---

func _item_to_species(item_id: StringName) -> StringName:
	var mapping := {
		"baby_chick": "chicken",
		"baby_bunny": "rabbit",
		"baby_duck": "duck",
		"baby_kitten": "cat",
		"baby_puppy": "dog",
		"baby_lamb": "sheep",
		"baby_calf": "cow",
		"baby_fawn": "deer",
		"baby_fox": "fox",
		"baby_owl": "owl",
	}
	return StringName(mapping.get(str(item_id), ""))


func _has_space_for(species: StringName) -> bool:
	var spec: Dictionary = SPECIES_DATA[str(species)]
	var needed_building: String = spec["building"]
	var capacity := get_building_capacity(StringName(needed_building))
	var current := 0
	for aid in animals:
		var a: AnimalData = animals[aid]
		if SPECIES_DATA[str(a.species)]["building"] == needed_building:
			current += 1
	# every species needs its building: no matching building (capacity 0) means no space, not "free range"
	return capacity > 0 and current < capacity


func _find_building_with_space(species: StringName) -> StringName:
	var spec: Dictionary = SPECIES_DATA[str(species)]
	var needed_building: String = spec["building"]
	var capacity: int = BUILDINGS[needed_building]["capacity"]

	for bid in buildings:
		var b: BuildingData = buildings[bid]
		if b.building_type == StringName(needed_building) and b.is_built:
			if b.animals_inside.size() < capacity:
				return bid
	return &""


func _random_animal_name() -> String:
	var names := [
		"Mjau", "Pip", "Fnug", "Blomst", "Stjerne", "Måne", "Sol", "Sky",
		"Nusse", "Fnis", "Boble", "Karambol", "Nødder", "Kastanje", "Bøge",
		"Egern", "Mospus", "Lyng", "Klokke", "Solsort", "Musling", "Perle",
	]
	return names[randi() % names.size()]


func _notify_cannot_afford() -> void:
	EventBus.notification_posted.emit(
		tr("NOTIF_NO_GOLD_TITLE"),
		tr("NOTIF_NO_GOLD_MSG"),
		"gold"
	)


func get_all_animals() -> Array:
	return animals.values()


func get_animal(animal_id: StringName) -> AnimalData:
	return animals.get(animal_id, null)


func get_animals_by_species(species: StringName) -> Array:
	var out: Array = []
	for aid in animals:
		var a: AnimalData = animals[aid]
		if a.species == species:
			out.append(a)
	return out


func get_happiness_level(animal: AnimalData) -> String:
	if animal.happiness >= 80: return "very_happy"
	if animal.happiness >= 60: return "happy"
	if animal.happiness >= 40: return "content"
	if animal.happiness >= 20: return "unhappy"
	return "miserable"


# --- Save/Load ---

func to_dict() -> Dictionary:
	var animal_dict := {}
	for aid in animals:
		animal_dict[aid] = (animals[aid] as AnimalData).to_dict()
	var building_dict := {}
	for bid in buildings:
		building_dict[bid] = (buildings[bid] as BuildingData).to_dict()
	return {
		"v": SAVE_VERSION,
		"animals": animal_dict,
		"buildings": building_dict,
		"counter": _animal_counter,
	}


## Pure validation also used by SaveManager before selecting a slot or replacing a backup.
func validate_dict(data: Dictionary) -> bool:
	if not _valid_count(data.get("v", 1)) or int(data.get("v", 1)) < 1 or int(data.get("v", 1)) > SAVE_VERSION:
		return false
	if not (data.get("animals", {}) is Dictionary) or not (data.get("buildings", {}) is Dictionary) or not _valid_count(data.get("counter", 0)):
		return false
	for id in data.get("animals", {}):
		var record: Variant = data["animals"][id]
		if not _valid_id(id) or not (record is Dictionary):
			return false
		var d: Dictionary = record
		if not _valid_id(d.get("species")) or not SPECIES_DATA.has(str(d["species"])):
			return false
		if not _valid_id(d.get("id", id)) or str(d.get("id", id)) != str(id):
			return false
		for field in ["age_days", "bond_level", "last_fed_day", "last_product_day", "products_ready"]:
			if not _valid_count(d.get(field, 0)):
				return false
		for field in ["happiness", "hunger", "bond_xp"]:
			var value: Variant = d.get(field, 0.0)
			if not _valid_number(value) or float(value) < 0.0 or (field != "bond_xp" and float(value) > 100.0):
				return false
		if not (d.get("name", "") is String) or not (d.get("is_baby", true) is bool) or not (d.get("building_id", "") is String or d.get("building_id", "") is StringName):
			return false
	for id in data.get("buildings", {}):
		var record: Variant = data["buildings"][id]
		if not _valid_id(id) or not (record is Dictionary):
			return false
		var d: Dictionary = record
		if not _valid_id(d.get("building_type")) or not BUILDINGS.has(str(d["building_type"])):
			return false
		if not _valid_id(d.get("id", id)) or str(d.get("id", id)) != str(id):
			return false
		if not _valid_count(d.get("built_day", 0)) or not (d.get("is_built", false) is bool) or not (d.get("animals_inside", []) is Array):
			return false
		for animal_id in d.get("animals_inside", []):
			if not _valid_id(animal_id):
				return false
	return true


static func _valid_id(value: Variant) -> bool:
	return (value is String or value is StringName) and str(value) != ""


static func _valid_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _valid_count(value: Variant) -> bool:
	return _valid_number(value) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and float(value) == floorf(float(value))


## Old records used the seasonal day number. Resolve it to the most recent occurrence on the loaded calendar.
func _legacy_day(value: int) -> int:
	if value == 0:
		return 0
	return maxi(GameManager.total_day() - posmod(GameManager.day - value, GameManager.days_per_season()), 0)


func from_dict(data: Dictionary) -> bool:
	if not validate_dict(data):
		return false
	var restored_animals := {}
	var restored_buildings := {}
	var legacy := int(data.get("v", 1)) < SAVE_VERSION
	var animal_dict: Dictionary = data.get("animals", {})
	for aid in animal_dict:
		var animal := AnimalData.from_dict(animal_dict[aid])
		animal.id = StringName(str(aid))
		if legacy:
			animal.last_fed_day = _legacy_day(animal.last_fed_day)
			animal.last_product_day = _legacy_day(animal.last_product_day)
		restored_animals[animal.id] = animal
	var building_dict: Dictionary = data.get("buildings", {})
	for bid in building_dict:
		var building := BuildingData.from_dict(building_dict[bid])
		building.id = StringName(str(bid))
		if legacy:
			building.built_day = _legacy_day(building.built_day)
		restored_buildings[building.id] = building
	animals = restored_animals
	buildings = restored_buildings
	_animal_counter = int(data.get("counter", 0))
	return true
