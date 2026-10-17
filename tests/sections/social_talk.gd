extends RefCounted
const SECTION := "social_talk"
const Talk := preload("res://scripts/social/talk/social_talk.gd")
const Bridge := preload("res://scripts/social/talk/dialogue_bridge.gd")

class Keys extends Node:
	var revision := 1
	var corpus: PackedStringArray = []
	func all_keys() -> PackedStringArray:
		return corpus

func run(t) -> void:
	await t.go_menu()
	var sm: Node = SocialFixture.fresh(t, 10)
	var lr: Node = t.autoload("LuaRuntime")
	var npc := "gardener_hoppe"
	var page := Bridge.decorate(npc, {})
	t.check("decorate_on_empty_module_has_greeting_and_close", page.lines.size() == 1 and str(page.lines[0].text_key).begins_with("SOC_GARDENER_HOPPE_FIRST_") and page.choices[-1].action == "close")
	t.expect(Talk.line(npc, "SOC_GARDENER_HOPPE_FIRST_1_V").voice_key == "voice/gardener_hoppe/first_1_v", "Voice suffix resolves to the indexed NPC path")
	var no_social := {"social": false, "lines": [{"id": "intro"}], "choices": []}
	t.expect(Bridge.decorate(npc, no_social) == no_social, "social=false preserves authored first-meeting scenes")
	sm.on_conversation_finished(npc, 1, true)
	var repeat := Bridge.decorate(npc, {"lines": [{"id": "authored"}]})
	t.expect(repeat.lines.size() == 1 and repeat.lines[0].id == "authored", "Once met today, authored pages do not get another greeting")
	SocialFixture.jump(11)
	var tomorrow := Bridge.decorate(npc, {"lines": [{"id": "authored"}]})
	t.expect(tomorrow.lines.size() == 2 and str(tomorrow.lines[0].text_key).contains("GREET"), "The next day adds one greeting before the authored page")
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"carrot", 1)
	var gifted := Bridge.decorate(npc, {})
	t.expect("give_gift" in gifted.choices.map(func(c): return str(c.action)), "A data-only citizen exposes the gift picker")
	sm.debug_set_hearts(npc, 8)
	var many := {"lines": [], "choices": []}
	for i in 8:
		many.choices.append({"id": str(i), "action": "open_journal", "text_key": "UI_JOURNAL"})
	var collapsed := Bridge.decorate(npc, many)
	t.check("choices_limit_5", collapsed.choices.size() == 5 and collapsed.choices[3].action == "social_more" and collapsed.choices[3].choices.size() >= 5 and collapsed.choices[4].action == "close")
	t.expect(Bridge.action(npc, "social_more", collapsed.choices[3]).page.choices[-1].action == "close", "Overflow retains its choices and a closing row")
	# Real topic pages teach one authored loved item only after they are read.
	var topic := Bridge.topic_page(npc)
	t.expect(not topic.is_empty() and not Bridge.finish_topic(npc, topic, false, 1) and sm.row_of(npc).kn.is_empty(), "Cancelling a topic never teaches its item")
	t.expect(Bridge.finish_topic(npc, topic, true, 1), "Reading the topic commits its daily use")
	t.check("topic_reveals_taste_once", sm.row_of(npc).kn.get("carrot") == "love" and sm.row_of(npc).rv == 1 and not Bridge.finish_topic(npc, topic, true, 1))
	t.check("topics_one_per_day", Bridge.topics(npc).is_empty())
	var saved: Dictionary = sm.to_dict()
	sm.reset()
	sm.from_dict(saved)
	t.expect(Bridge.topics(npc).is_empty() and sm.row_of(npc).rv == 1, "Topic day and reveal bits survive a save roundtrip")
	SocialFixture.jump(12)
	topic = Bridge.topic_page(npc)
	t.expect(topic.topic.item == "moonflower" and Bridge.finish_topic(npc, topic, true, 1), "The next day reveals the next hearts-gated preference")
	for hearts in range(11):
		t.expect(Talk.band(hearts) == (0 if hearts < 2 else 1 if hearts < 5 else 2 if hearts < 8 else 3), "Hearts band for %d" % hearts)
	# A fixture corpus proves specificity, variant gaps and cache invalidation.
	var keys := Keys.new()
	keys.corpus = ["BDAY_GARDENER_HOPPE_GREET_1", "SOC_GARDENER_HOPPE_GREET_H2_AFTEN_1", "SOC_GARDENER_HOPPE_GREET_H2_1", "SOC_GARDENER_HOPPE_GREET_H2_3", "SOC_ARCH_GARDENER_GREET_H2_1", "SOC_ARCH_GARDENER_GREET_H2_2", "SOC_ANY_GREET_1"]
	Svc.override("LocalizationManager", keys)
	var ctx := {"hearts": 6, "daypart": "aften", "weather": "klart", "season": "foraar", "birthday": true, "festival": ""}
	t.check("cascade_specificity", Talk.pick(npc, "GREET", ctx) == "BDAY_GARDENER_HOPPE_GREET_1")
	ctx.birthday = false
	t.expect(Talk.pick(npc, "GREET", ctx) == "SOC_GARDENER_HOPPE_GREET_H2_AFTEN_1", "Day-part authored line precedes broad band pool")
	ctx.daypart = "morgen"
	t.expect(Talk.pick(npc, "GREET", ctx).begins_with("SOC_GARDENER_HOPPE_GREET_H2_"), "Broad band remains usable in every daypart")
	t.expect(Talk.variants("SOC_GARDENER_HOPPE_GREET_H2").size() == 2, "Gapped numbered variants are indexed")
	var last := ""
	var no_repeat := true
	for i in 100:
		var key := Talk.pick(npc, "GREET", ctx)
		no_repeat = no_repeat and key != last
		last = key
	t.check("no_immediate_repeat", no_repeat)
	keys.corpus.append("GIFT_GARDENER_HOPPE_LOVE_1_V")
	keys.revision += 1
	t.expect(Talk.pick(npc, "GIFT_LOVE", ctx) == "GIFT_GARDENER_HOPPE_LOVE_1_V", "Corpus revision invalidates family caches")
	var weather_hits := 0
	var season_hits := 0
	keys.corpus.append_array(["SOC_GARDENER_HOPPE_GREET_WX_REGN_1", "SOC_GARDENER_HOPPE_GREET_SOMMER_1"])
	keys.revision += 1
	ctx.weather = "regn"
	ctx.season = "sommer"
	for day in range(1, 1001):
		SocialFixture.jump(day)
		var key := Talk.pick(npc, "GREET", ctx)
		weather_hits += int(key.contains("WX_REGN"))
		season_hits += int(key.contains("SOMMER"))
	t.check("weather_and_season_probabilities", weather_hits > 350 and weather_hits < 750 and season_hits > 30 and season_hits < 200, "Deterministic weather/season sample: %d/%d" % [weather_hits, season_hits])
	Svc.clear_overrides()
	keys.free()
	Talk.invalidate()
	SocialFixture.jump(10)
	ctx = sm.dialogue_context(npc)
	Talk.pick(npc, "GREET", ctx)
	var start := Time.get_ticks_usec()
	for i in 3000:
		Talk.pick(npc, "GREET", ctx)
	var micros := float(Time.get_ticks_usec() - start) / 3000.0
	t.check("pick_under_20us", micros < 20.0, "Cached social line pick: %.2f us" % micros)
	# Keep the fallback test independent of how much keeper copy is installed.
	var no_keeper_keys := Keys.new()
	Svc.override("LocalizationManager",no_keeper_keys)
	Talk.invalidate()
	t.expect(Talk.greeting_for_shop("bakery").text_key == lr.get_shop("bakery").greeting_key, "Missing keeper variants fall back to the actual shop greeting")
	Svc.clear_overrides()
	no_keeper_keys.free()
	Talk.invalidate()
	t.expect(Talk.bubble_for("guard_oak") == "quest", "Quest bubble has first priority")
	sm.remember_line(npc, "GIFT_LOVE", "")
	var first_gift := Talk.pick(npc, "GIFT_LOVE", ctx)
	t.expect(first_gift.begins_with("GIFT_GARDENER_HOPPE_LOVE_"), "Gift reaction uses the citizen's own line first")
	t.expect(Talk.pick(npc, "GIFT_LOVE", ctx) != first_gift, "A repeated gift can use the archetype pool to avoid repeating one personal line")
	SocialFixture.jump(5)
	t.expect(Talk.pick(npc, "GREET", sm.dialogue_context(npc)).begins_with("BDAY_"), "Birthday greeting wins over ordinary context")
	SocialFixture.install({}, {"events": {"test_heart": {"meta": {"npc": npc, "hearts": 0}}}})
	t.expect(Talk.bubble_for(npc) == "heart", "A ready heart event precedes the birthday bubble")
	var ready := Bridge.decorate(npc, {})
	t.expect("start_event" in ready.choices.map(func(c): return str(c.action)), "Ready heart events get an explicit conversation choice")
	SocialFixture.uninstall()
	t.expect(not Bridge.action(npc, "custom_content_action", {}).handled, "Content actions fall through to Npc2D's EventBus dispatch")
	var other := "bathkeeper_sofus"
	Bridge.decorate(other, no_social)
	sm.on_conversation_finished(other, 1, true)
	t.expect(sm.met(other), "social=false scenes still count their read conversation as a meeting")
	SocialFixture.uninstall()
	t.new_game()
