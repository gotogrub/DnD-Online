extends RefCounted
class_name MovementService
## Validates movement intents and prepares authoritative movement results.


func can_move_actor(peer_id: int, actor_id: String, to_tile: Vector2i) -> bool:
	return bool(validate_move(peer_id, actor_id, to_tile).get("ok", false))


func validate_move(peer_id: int, actor_id: String, to_tile: Vector2i) -> Dictionary:
	if not SessionState.has_actor(actor_id):
		return _error("Actor does not exist.")
	var actor := SessionState.get_actor(actor_id)
	if not SessionState.is_gm(peer_id) and int(actor.get(EntityData.OWNER_PEER_ID, 0)) != peer_id:
		return _error("You do not control this actor.")
	if not TileRules.is_walkable(to_tile):
		return _error("Target tile is not walkable.")
	var path := TileRules.find_path(actor.get(EntityData.TILE, Vector2i.ZERO), to_tile, actor_id)
	if path.is_empty():
		return _error("No path to target tile.")
	var cost := TileRules.path_cost(path)
	var encounter_state := SessionState.encounter
	if bool(encounter_state.get("active", false)):
		if str(encounter_state.get("current_actor_id", "")) != actor_id and not SessionState.is_gm(peer_id):
			return _error("It is not this actor's turn.")
		if int(actor.get(EntityData.AP, 0)) < cost:
			return _error("Not enough AP.")
	return {"ok": true, "path": path, "cost": cost}


func build_move_result(actor_id: String, to_tile: Vector2i) -> Dictionary:
	if not SessionState.has_actor(actor_id):
		return _error("Actor does not exist.")
	var actor := SessionState.get_actor(actor_id)
	var from_tile: Vector2i = actor.get(EntityData.TILE, Vector2i.ZERO)
	var path := TileRules.find_path(from_tile, to_tile, actor_id)
	if path.is_empty():
		return _error("No path to target tile.")
	return {
		"ok": true,
		"actor_id": actor_id,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"path": path,
		"cost": TileRules.path_cost(path),
	}


func apply_move(move_result: Dictionary) -> void:
	if not bool(move_result.get("ok", false)):
		return
	var actor_id := str(move_result.get("actor_id", ""))
	var actor := SessionState.get_actor(actor_id)
	if actor.is_empty():
		return
	actor[EntityData.TILE] = move_result.get("to_tile", actor.get(EntityData.TILE, Vector2i.ZERO))
	if bool(SessionState.encounter.get("active", false)):
		actor[EntityData.AP] = max(int(actor.get(EntityData.AP, 0)) - int(move_result.get("cost", 0)), 0)
	SessionState.set_actor(actor)


func _error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
