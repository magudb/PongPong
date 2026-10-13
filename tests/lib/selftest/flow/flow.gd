extends RefCounted
## Harness self-test: the flow helpers (new_game / start_world / ensure_world / days / go_menu / boot) on the real game.
## No boot stage needed (--no-boot): the section starts the world itself.
const SECTION := "flow"

func run(t) -> void:
	var gm: Node = t.autoload("GameManager")
	# the model reset alone
	gm.day = 17
	t.new_game("fairy", "Hanne", "Hannegaard")
	t.expect_eq(gm.player_name, "Hanne", "new_game() stores the player name")
	t.expect_eq(gm.farm_name, "Hannegaard", "new_game() stores the farm name")
	t.expect_eq(int(gm.character_type), 1, "new_game(\"fairy\") selects the fairy")
	t.expect_eq(int(gm.day), 1, "new_game() resets the calendar")
	t.expect_eq(t.character, "fairy", "new_game() remembers the character on t")
	# a fresh world without the menus
	t.expect(await t.start_world("hobbit"), "start_world() reaches a world with a player")
	t.expect(t.in_world() and t.world() != null and t.player() != null, "in_world() / world() / player()")
	t.expect_eq(int(gm.character_type), 2, "start_world(\"hobbit\") selects the hobbit")
	t.expect(await t.ensure_world(), "ensure_world() reuses the running world")
	# days through the real end_day path
	var d0: int = gm.day
	await t.days(3)
	t.expect_eq(int(gm.day), d0 + 3, "days(3) advances three days through GameManager.end_day()")
	# back to a live menu, then the real UI flow again
	t.expect(await t.go_menu(), "go_menu() returns to the main menu")
	t.expect_eq(t.scene_path(), t.MENU_SCENE, "the main menu is the current scene")
	t.expect(not t.tree.paused, "the tree is not paused in the menu")
	t.expect(await t.boot("animal"), "boot() walks the real menus into a world")
	t.expect(t.in_world() and t.player() != null, "boot() ends in the world with a player")
	t.expect_eq(int(gm.character_type), 0, "boot(\"animal\") selects the animal")
