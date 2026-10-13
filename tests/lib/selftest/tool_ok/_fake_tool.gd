extends SceneTree
## Harness self-test helper (a `-s` driver; the leading underscore keeps it from being discovered as a section): prints PASS/FAIL ids like tests/tools/check_project.gd.
func _initialize() -> void:
	print("PASS fake.one")
	print("FAIL fake.two")
	print("PASS fake.three")
	quit(1)
