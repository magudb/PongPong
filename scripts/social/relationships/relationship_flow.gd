class_name RelationshipFlow
extends RefCounted
## Special gifts never enter the ordinary gift ledger. The picker obtains explicit
## consent; the transaction rechecks every condition against live state.
const TOKENS := ["hjertebuket","loefteagern"]
const WEDDING := "bryllupsfesten"
static var _busy := false

static func is_token(item: String) -> bool:return item in TOKENS
static func state(npc: String) -> int:return int(SocialManager.row_of(npc,false).get("rs",0))
static func reason(npc: String,item: String) -> String:
	if not is_token(item):return "no_item"
	if not SocialManager.can_befriend(npc) or not bool(SocialData.citizen(npc).get("partner",false)):return "PARTNER_NOT_ADULT"
	var rs := state(npc)
	if item == "hjertebuket":
		if rs > 0:return "PARTNER_ALREADY"
		return "" if SocialManager.hearts(npc)>=int(Svc.lua_config("relationships.heartfriend_hearts",8)) else "PARTNER_WAIT"
	if rs>=2:return "PARTNER_ALREADY"
	if rs!=1 or SocialManager.hearts(npc)<int(Svc.lua_config("relationships.engagement_hearts",10)):return "PARTNER_WAIT"
	if not SocialManager.partner().is_empty():return "PARTNER_OTHER_PROMISE"
	if SocialManager.today()-SocialManager.event_stamp("heartfriend:"+npc)<int(Svc.lua_config("relationships.heartfriend_days",7)):return "PARTNER_DAYS"
	if HomeManager.tier<int(Svc.lua_config("relationships.min_home_tier",3)):return "PARTNER_HOME"
	return ""

static func offer(npc: String,item: String) -> Dictionary:
	if not is_token(item):return {}
	return {"special":true,"refusal":reason(npc,item),"title":"PARTNER_GIFT_TITLE","body":"PARTNER_BOUQUET_CONFIRM" if item=="hjertebuket" else "PARTNER_ACORN_CONFIRM","ok":"PARTNER_GIVE","cancel":"PARTNER_STAY_FRIENDS"}

static func give(npc: String,item: String,confirmed := false) -> Dictionary:
	if _busy:return {"ok":false,"reason":"busy"}
	var why := reason(npc,item)
	if why!="":return {"ok":false,"reason":"relationship","message_key":why}
	if not confirmed:return {"ok":false,"reason":"confirmation_required"}
	if EconomyManager.count_item(StringName(item))<1:return {"ok":false,"reason":"no_item"}
	_busy = true
	var rs := 1 if item=="hjertebuket" else 2
	var day := SocialManager.today()
	var wedding := next_wedding(day+int(Svc.lua_config("relationships.wedding_wait",7))) if rs==2 else 0
	var result := {"ok":false,"reason":"no_item"}
	EconomyManager.defer_notifications(func() -> void:
		if not EconomyManager.remove_item(StringName(item),1):return
		SocialManager.commit_relationship(npc,rs,day,wedding)
		result.clear()
		result.merge({"ok":true,"item":item,"special":true,"relationship":rs,"points":0,"class":"love","hearts":SocialManager.hearts(npc)})
		EconomyManager.after_transaction(func() -> void:
			EventBus.game_event.emit(&"relationship_changed",{"npc":npc,"stage":str(SocialManager.stage(npc)),"partner":rs>=2})
			if rs==2:announce_date())
	)
	_busy = false
	return result

static func reaction_lines(npc: String,result: Dictionary) -> Array:
	var prefix := "PARTNER_ENGAGED" if int(result.get("relationship",0))==2 else "PARTNER_"+str({"gardener_hoppe":"HOPPE","carpenter_brumme":"BRUMME","baker_maja":"MAJA","beekeeper_birk":"BIRK"}.get(npc,"ARCH_"+str(SocialData.citizen(npc).get("archetype","wanderer")).to_upper()))
	return [{"text_key":prefix+"_1"},{"text_key":prefix+"_2"}]

## Use the shared staged runtime after consent, keeping the approved camera,
## clear-floor placement, skip behaviour and modal cleanup of every other scene.
static func play_scene(npc: String,result: Dictionary,actor: WeakRef) -> bool:
	var citizen: Node = actor.get_ref() if actor!=null else null
	var director := SocialManager.get_node_or_null("EventDirector") as SocialEventDirector
	if citizen==null or director==null or director.runner.active!="":return false
	var runtime := director.runner
	var old := runtime.actor_resolver
	var tree := citizen.get_tree()
	runtime.actor_resolver = func(id: String) -> Node:
		if id==npc:return actor.get_ref()
		if old.is_valid():return old.call(id)
		return tree.get_first_node_in_group("player") if id=="player" else NpcDirector.node_of(id)
	var place := str(Routines.where_is(npc,Routines.now_ctx()).get("place",""))
	var steps: Array = [{"act":"fade","to":"black","seconds":0.15},
		{"act":"stand","who":npc,"mark":place.get_slice(".",1),"clear_view":true},
		{"act":"camera","target":npc,"zoom":0.9,"seconds":0.7},
		{"act":"face","who":npc,"dir":"S"},{"act":"fade","to":"clear","seconds":0.15}]
	for line in reaction_lines(npc,result):steps.append({"act":"say","who":npc,"text_key":str(line.text_key)})
	steps.append({"act":"end"})
	var played := await runtime.play("ev_relationship_"+npc+"_"+str(result.get("relationship",1)),{"meta":{"trigger":"automatic","npc":npc,"once":true},"steps":steps})
	runtime.actor_resolver = old
	return played

static func fixed_on(td: int) -> bool:
	var date := CalendarUtil.date_of(td)
	for id in SocialData.festivals():
		var meta := LuaData.dict(SocialData.festival(str(id)).get("meta",{}))
		if str(meta.get("season",""))==str(date.season) and int(meta.get("day",0))==int(date.day):return true
	return false

static func next_wedding(from_day: int) -> int:
	var day := from_day+posmod(6-CalendarUtil.weekday_of(from_day),7)
	for _week in 60:
		if not fixed_on(day-1) and not fixed_on(day) and not fixed_on(day+1):return day
		day += 7
	return day

static func festival_on(day: int) -> bool:
	var partner := SocialManager.partner()
	return int(partner.get("wedding",0))==day and int(partner.get("stage",0))>=2

static func wedding_definition() -> Dictionary:
	var out := LuaData.dict(Svc.lua_config("relationships.wedding",{})).duplicate(true)
	if out.is_empty():return out
	var partner := SocialManager.partner()
	var date := CalendarUtil.date_of(int(partner.get("wedding",1)))
	out.meta["season"] = str(date.season)
	out.meta["day"] = int(date.day)
	out.meta["first"] = [str(partner.get("id",""))]
	return out

## Any attending keeper with work after the festival gets a measured return
## margin. The existing authored early departure remains a minimum.
static func keeper_departure(npc: String,day: int,end: float,post: String,authored: float) -> float:
	var lead := authored
	for id in Hours.registry():
		var b := Hours.building(str(id))
		if str(b.get("keeper",""))!=npc or not b.has("hours") or CalendarUtil.weekday_of(day) in Hours.closed_days(b):continue
		var hours := Hours.hours_on(b,CalendarUtil.weekday_of(day))
		if float(hours[1])<=end or str(b.get("post",""))=="":continue
		var travel := Routines._move_seg(post,str(b.post),0.0,npc)
		lead = maxf(lead,end-maxf(end,float(hours[0]))+float(travel.t1)*1.5+0.25)
	return lead

static func wedding_scene() -> Dictionary:
	var npc := str(SocialManager.partner().get("id",""))
	return {"meta":{"trigger":"automatic","festival":WEDDING,"once":true},"steps":[
		{"act":"fade","to":"black","seconds":0.15},
		{"act":"stand","who":npc,"mark":"fest_hyggetorv_gather_1","clear_view":true},
		{"act":"camera","target":npc,"seconds":0.7},{"act":"face","who":npc,"target":"player"},
		{"act":"fade","to":"clear","seconds":0.15},
		{"act":"say","who":"mayor_lyra","text_key":"PARTNER_WEDDING_HOST"},
		{"act":"say","who":npc,"text_key":"PARTNER_WEDDING_1"},
		{"act":"say","who":npc,"text_key":"PARTNER_WEDDING_2"},{"act":"end"}]}

static func marry() -> bool:
	var p := SocialManager.partner()
	if int(p.get("stage",0))!=2 or not festival_on(SocialManager.today()):return false
	if not SocialManager.event_seen("ev_bryllupsfesten_open") or SocialManager.event_stamp("day:ev_bryllupsfesten_open")!=SocialManager.today():return false
	SocialManager.commit_relationship(str(p.id),3,SocialManager.today(),int(p.wedding))
	EventBus.game_event.emit(&"relationship_changed",{"npc":str(p.id),"stage":"gift","partner":true})
	EventBus.notification_posted.emit(TranslationServer.translate("FEST_BRYLLUPSFESTEN_NAME"),TranslationServer.translate("PARTNER_WEDDING_HOME"),"social")
	return true

static func announce_date() -> void:
	var p := SocialManager.partner()
	var date := CalendarUtil.date_of(int(p.get("wedding",1)))
	var name := TranslationServer.translate("UI_SEASON_"+str(date.season).to_upper())
	EventBus.notification_posted.emit(TranslationServer.translate("FEST_BRYLLUPSFESTEN_NAME"),TranslationServer.translate("PARTNER_DATE") % [name,int(date.day)],"social")

static func flush() -> void:
	var p := SocialManager.partner()
	if int(p.get("stage",0))!=2:return
	if marry():return
	var day := SocialManager.today()
	if day>int(p.get("wedding",day)) or (day==int(p.get("wedding",0)) and GameManager.hour>=20):
		SocialManager.reschedule_wedding(next_wedding(maxi(day+1,int(p.wedding)+7)))
		EventBus.notification_posted.emit(TranslationServer.translate("FEST_BRYLLUPSFESTEN_NAME"),TranslationServer.translate("PARTNER_POSTPONED"),"social")
		announce_date()
