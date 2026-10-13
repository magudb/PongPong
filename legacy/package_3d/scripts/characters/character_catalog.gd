extends RefCounted
## Stable skin IDs: existing save files remain compatible.

const CHARACTERS := [
	&"bat", &"cat", &"bear", &"rabbit", &"fairy", &"monkey", &"capybara",
	&"fox", &"raccoon", &"penguin", &"hedgehog", &"frog",
]
const FLYERS := [&"bat", &"fairy"]
const NPC_MODELS := {
	&"mayor_lyra": &"fairy", &"fairy_lily": &"fairy", &"fairy_wizard": &"fairy",
	&"baker_maja": &"rabbit", &"smith_thorin": &"hedgehog",
	&"merchant_pip": &"monkey", &"guard_oak": &"bear", &"farmer_rosa": &"capybara",
}

static func model_for_skin(skin: StringName) -> StringName:
	var text := String(skin)
	if text.begins_with("fairy_"):
		return &"fairy"
	var candidate := StringName(text.trim_prefix("animal_"))
	return candidate if candidate in CHARACTERS else &""

static func skin_for_model(model: StringName) -> StringName:
	return &"fairy_meadow" if model == &"fairy" else StringName("animal_" + String(model))

static func collider_for_skin(skin: StringName) -> Vector2:
	# Height, radius. Ears, tails and wings are decorative, not separate colliders.
	match model_for_skin(skin):
		&"bat": return Vector2(1.08, 0.36)
		&"fairy": return Vector2(1.55, 0.30)
		&"capybara": return Vector2(1.35, 0.40)
		_: return Vector2(1.60, 0.38)
