extends RefCounted
class_name EncounterService
## Tracks encounter mode, initiative order, turn ownership, and AP bookkeeping.


func start_encounter(initiative: Array = []) -> Dictionary:
	var order := initiative.duplicate(true)
	if order.is_empty():
		for actor_id in SessionState.actors.keys():
			order.append({"actor_id": actor_id, "initiative": 0})
	order.sort_custom(_sort_initiative_desc)
	var first_actor := str(order[0].get("actor_id", "")) if not order.is_empty() else ""
	var state := {
		"active": true,
		"round": 1,
		"turn_index": 0 if not order.is_empty() else -1,
		"initiative": order,
		"current_actor_id": first_actor,
	}
	_reset_actor_ap(first_actor)
	SessionState.set_encounter(state)
	return state


func end_encounter() -> Dictionary:
	var state := SessionState.encounter.duplicate(true)
	state["active"] = false
	state["turn_index"] = -1
	state["current_actor_id"] = ""
	SessionState.set_encounter(state)
	return state


func next_turn() -> Dictionary:
	var state := SessionState.encounter.duplicate(true)
	var order: Array = state.get("initiative", [])
	if order.is_empty():
		return state
	var next_index := int(state.get("turn_index", -1)) + 1
	var round_number := int(state.get("round", 1))
	if next_index >= order.size():
		next_index = 0
		round_number += 1
	var actor_id := str(order[next_index].get("actor_id", ""))
	state["turn_index"] = next_index
	state["round"] = round_number
	state["current_actor_id"] = actor_id
	_reset_actor_ap(actor_id)
	SessionState.set_encounter(state)
	return state


func can_actor_act(actor_id: String) -> bool:
	var state := SessionState.encounter
	if not bool(state.get("active", false)):
		return true
	return str(state.get("current_actor_id", "")) == actor_id


func set_initiative(actor_id: String, initiative: int) -> Dictionary:
	var state := SessionState.encounter.duplicate(true)
	var order: Array = state.get("initiative", [])
	var found := false
	for item in order:
		if str(item.get("actor_id", "")) == actor_id:
			item["initiative"] = initiative
			found = true
			break
	if not found:
		order.append({"actor_id": actor_id, "initiative": initiative})
	state["initiative"] = order
	SessionState.set_encounter(state)
	return state


func _reset_actor_ap(actor_id: String) -> void:
	if actor_id.is_empty() or not SessionState.has_actor(actor_id):
		return
	var actor := SessionState.get_actor(actor_id)
	actor[EntityData.AP] = int(actor.get(EntityData.MAX_AP, MvpConstants.DEFAULT_MAX_AP))
	SessionState.set_actor(actor)


func _sort_initiative_desc(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("initiative", 0)) > int(b.get("initiative", 0))
