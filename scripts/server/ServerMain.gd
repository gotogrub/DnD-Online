extends Node
class_name ServerMain
## Coordinates server-side MVP services without owning gameplay rules directly.

var world_state := WorldState.new()
var entity_service := EntityService.new()
var movement_service := MovementService.new()
var chat_service := ChatService.new()
var encounter_service := EncounterService.new()
var gm_command_service := GMCommandService.new(entity_service, movement_service, encounter_service, chat_service)


func boot(options: Dictionary = {}) -> void:
	SessionState.reset()
	SessionState.map_id = str(options.get("map_id", MvpConstants.DEFAULT_MAP_ID))
	world_state.clear()
	world_state.map_id = SessionState.map_id


func shutdown() -> void:
	SessionState.reset()
	world_state.clear()


func tick(_delta: float) -> void:
	world_state.players = SessionState.players.duplicate(true)
	world_state.actors = SessionState.actors.duplicate(true)
	world_state.encounter = SessionState.encounter.duplicate(true)
	world_state.chat_log = SessionState.chat_log.duplicate(true)


func register_player(peer_id: int, player_name: String, role := MvpConstants.ROLE_PLAYER, spawn_tile := Vector2i.ZERO) -> Dictionary:
	var player_id := "player_%d" % peer_id
	var actor := entity_service.create_player_actor(player_id, spawn_tile, peer_id, player_name)
	var player := EntityData.make_player(peer_id, player_id, player_name, role, actor[EntityData.ACTOR_ID])
	SessionState.set_player(player)
	return {
		"player": player,
		"actor": actor,
		"snapshot": SessionState.get_snapshot(),
	}


func unregister_player(peer_id: int) -> void:
	var player := SessionState.get_player(peer_id)
	var actor_id := str(player.get(EntityData.ACTOR_ID, ""))
	if not actor_id.is_empty():
		entity_service.remove_actor(actor_id)
	SessionState.remove_player(peer_id)


func handle_chat_or_command(peer_id: int, text: String) -> Dictionary:
	var parsed := CommandRouter.route_chat_message(peer_id, text)
	if parsed.get("type", "") == "chat":
		return {"ok": true, "type": "chat", "message": chat_service.submit_message(peer_id, text)}
	if parsed.get("type", "") == "command":
		return gm_command_service.handle_command(peer_id, parsed)
	return {"ok": false, "error": parsed.get("error", "Invalid input.")}


func handle_move_intent(peer_id: int, actor_id: String, to_tile: Vector2i) -> Dictionary:
	var validation := movement_service.validate_move(peer_id, actor_id, to_tile)
	if not bool(validation.get("ok", false)):
		return validation
	var move_result := movement_service.build_move_result(actor_id, to_tile)
	movement_service.apply_move(move_result)
	return move_result
