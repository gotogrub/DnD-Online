extends Node
class_name SessionStateSingleton
## Stores the current authoritative session snapshot on the server and a read-only cache on clients.

signal state_changed()
signal actors_changed()
signal actor_changed(actor_id: String)
signal actor_moved(actor_id: String, from_tile: Vector2i, to_tile: Vector2i)
signal actor_removed(actor_id: String)
signal chat_message_added(message: Dictionary)
signal encounter_changed(encounter_state: Dictionary)

var players := {}
var actors := {}
var selected_actor_id := ""
var encounter := {}
var map_id := ""
var chat_log: Array = []


func reset() -> void:
	players.clear()
	actors.clear()
	selected_actor_id = ""
	chat_log.clear()
	map_id = MvpConstants.DEFAULT_MAP_ID
	encounter = _default_encounter()
	actors_changed.emit()
	state_changed.emit()


func reset_local_debug_state() -> void:
	actors.clear()
	selected_actor_id = ""
	map_id = MvpConstants.DEFAULT_MAP_ID
	actors_changed.emit()
	state_changed.emit()


func apply_snapshot(snapshot: Dictionary) -> void:
	map_id = str(snapshot.get("map_id", MvpConstants.DEFAULT_MAP_ID))
	players = snapshot.get("players", {}).duplicate(true)
	actors = snapshot.get("actors", {}).duplicate(true)
	selected_actor_id = str(snapshot.get("selected_actor_id", selected_actor_id))
	encounter = snapshot.get("encounter", _default_encounter()).duplicate(true)
	chat_log = snapshot.get("chat_log", []).duplicate(true)
	actors_changed.emit()
	state_changed.emit()


func get_snapshot() -> Dictionary:
	return {
		"map_id": map_id,
		"players": players.duplicate(true),
		"actors": actors.duplicate(true),
		"selected_actor_id": selected_actor_id,
		"encounter": encounter.duplicate(true),
		"chat_log": chat_log.duplicate(true),
	}


func has_actor(actor_id: String) -> bool:
	return actors.has(actor_id)


func get_actor(actor_id: String) -> Dictionary:
	return actors.get(actor_id, {}).duplicate(true)


func create_actor(actor_id: String, kind: String, actor_name: String, tile: Vector2i, sprite := "", blocks_tile := true) -> Dictionary:
	if actor_id.is_empty():
		return {}
	var actor: Dictionary = EntityData.make_actor(
		actor_id,
		kind,
		0,
		actor_name,
		tile,
		_resolve_actor_sprite(kind, sprite),
		MvpConstants.DEFAULT_MAX_AP,
		blocks_tile
	)
	actors[actor_id] = actor.duplicate(true)
	actor_changed.emit(actor_id)
	actors_changed.emit()
	state_changed.emit()
	return actor.duplicate(true)


func set_actor(actor_data: Dictionary) -> void:
	var actor_id := str(actor_data.get(EntityData.ACTOR_ID, ""))
	if actor_id.is_empty():
		return
	actors[actor_id] = actor_data.duplicate(true)
	actor_changed.emit(actor_id)
	actors_changed.emit()
	state_changed.emit()


func move_actor(actor_id: String, tile: Vector2i) -> bool:
	if not actors.has(actor_id):
		return false
	var actor: Dictionary = actors[actor_id]
	var from_tile: Vector2i = actor.get(EntityData.TILE, Vector2i.ZERO)
	if from_tile == tile:
		return true
	actor[EntityData.TILE] = tile
	actors[actor_id] = actor
	actor_moved.emit(actor_id, from_tile, tile)
	actor_changed.emit(actor_id)
	state_changed.emit()
	return true


func get_actors() -> Dictionary:
	return actors.duplicate(true)


func remove_actor(actor_id: String) -> void:
	if not actors.erase(actor_id):
		return
	if selected_actor_id == actor_id:
		selected_actor_id = ""
	actor_removed.emit(actor_id)
	actors_changed.emit()
	state_changed.emit()


func set_player(player_data: Dictionary) -> void:
	var peer_id := int(player_data.get(EntityData.PEER_ID, 0))
	if peer_id == 0:
		return
	players[peer_id] = player_data.duplicate(true)
	state_changed.emit()


func remove_player(peer_id: int) -> void:
	if players.erase(peer_id):
		state_changed.emit()


func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {}).duplicate(true)


func get_role(peer_id: int) -> String:
	return str(players.get(peer_id, {}).get(EntityData.ROLE, ""))


func is_gm(peer_id: int) -> bool:
	return get_role(peer_id) == MvpConstants.ROLE_GM


func add_chat_message(message: Dictionary) -> void:
	chat_log.append(message.duplicate(true))
	chat_message_added.emit(message)
	state_changed.emit()


func set_encounter(encounter_state: Dictionary) -> void:
	encounter = encounter_state.duplicate(true)
	encounter_changed.emit(encounter.duplicate(true))
	state_changed.emit()


func _ready() -> void:
	if encounter.is_empty():
		reset()


func _default_encounter() -> Dictionary:
	return {
		"active": false,
		"round": 0,
		"turn_index": -1,
		"initiative": [],
		"current_actor_id": "",
	}


func _resolve_actor_sprite(kind: String, sprite: String) -> String:
	if sprite == MvpConstants.ACTOR_KIND_PLAYER or sprite == "player":
		return MvpConstants.DEFAULT_PLAYER_SPRITE
	if sprite == MvpConstants.ACTOR_KIND_NPC or sprite == "npc":
		return MvpConstants.DEFAULT_NPC_SPRITE
	if sprite == "enemy":
		return MvpConstants.DEFAULT_ENEMY_SPRITE
	if not sprite.is_empty():
		return sprite
	if kind == MvpConstants.ACTOR_KIND_PLAYER:
		return MvpConstants.DEFAULT_PLAYER_SPRITE
	if kind == MvpConstants.ACTOR_KIND_NPC:
		return MvpConstants.DEFAULT_NPC_SPRITE
	return ""
