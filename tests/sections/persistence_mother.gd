extends RefCounted
const SECTION := "persistence_mother"
const TIMEOUT_S := 180.0

# Identical real Mother vertical used by the cumulative boundary section, without
# the separate write-reentrancy experiment. Safe on original production APIs.
func run(t) -> void:
	await load("res://tests/sections/persistence_boundary.gd").new()._mother(t)
