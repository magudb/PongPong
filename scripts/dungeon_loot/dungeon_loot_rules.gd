class_name DungeonLootRules
extends RefCounted
## Pure delegate for LootService's plan -> fit -> deliver -> commit transaction.
static func depth_odds(cfg: Dictionary, tier: String, number: int, luck: float) -> Dictionary:
	return DungeonContainerRules.depth_odds(cfg,tier,number,luck)
static func roll_container(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonContainerRules.roll(state,req)
static func roll_node(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonNodeRules.roll_node(state,req)
static func roll_drop(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonNodeRules.roll_drop(state,req)
static func boss_result(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonRewardRules.boss_result(state,req)
static func roll_spot(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonRewardRules.roll_spot(state,req)
static func spot_state(state: Dictionary, req: Dictionary) -> StringName:
	return DungeonRewardRules.spot_state(state,req)
static func appraisal_quote(cfg: Dictionary, id: String) -> Dictionary:
	return DungeonRewardRules.appraisal_quote(cfg,id)
static func roll_appraisal(state: Dictionary, req: Dictionary) -> Dictionary:
	return DungeonRewardRules.roll_appraisal(state,req)
static func fits(plan: Dictionary, view: Dictionary) -> bool:
	return DungeonLootPlan.fits(plan,view)
static func commit(state: Dictionary, plan: Dictionary) -> Dictionary:
	return DungeonLootPlan.commit(state,plan)
static func unique_ready(state: Dictionary, day: int, days: int = 7) -> bool:
	return DungeonLootPlan.unique_ready(state,day,days)
static func from_dict(state: Dictionary) -> Dictionary:
	return DungeonLootState.from_dict(state)
