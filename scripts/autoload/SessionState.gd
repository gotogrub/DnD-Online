extends Node
class_name SessionStateSingleton
## Stores the current authoritative session snapshot on the server and a read-only cache on clients.

signal state_changed()
signal actor_changed(actor_id: String)
signal actor_removed(actor_id: String)
signal chat_message_added(message: Dictionary)
signal encounter_changed(encounter_state: Dictionary)

var players := {}
var actors := {}
var encounter := {}
var map_id := ""
var chat_log: Array = []


func reset() -> void:
	players.clear()
	actors.clear()
	chat_log.clear()
	map_id = MvpConstants.DEFAULT_MAP_ID
	encounter = _default_encounter()
	state_changed.emit()


func apply_snapshot(snapshot: Dictionary) -> void:
	map_id = str(snapshot.get("map_id", MvpConstants.DEFAULT_MAP_ID))
	players = snapshot.get("players", {}).duplicate(true)
	actors = snapshot.get("actors", {}).duplicate(true)
	encounter = snapshot.get("encounter", _default_encounter()).duplicate(true)
	chat_log = snapshot.get("chat_log", []).duplicate(true)
	state_changed.emit()


func get_snapshot() -> Dictionary:
	return {
		"map_id": map_id,
		"players": players.duplicate(true),
		"actors": actors.duplicate(true),
		"encounter": encounter.duplicate(true),
		"chat_log": chat_log.duplicate(true),
	}


func has_actor(actor_id: String) -> bool:
	return actors.has(actor_id)


func get_actor(actor_id: String) -> Dictionary:
	return actors.get(actor_id, {}).duplicate(true)


func set_actor(actor_data: Dictionary) -> void:
	var actor_id := str(actor_data.get(EntityData.ACTOR_ID, ""))
	if actor_id.is_empty():
		return
	actors[actor_id] = actor_data.duplicate(true)
	actor_changed.emit(actor_id)
	state_changed.emit()


func remove_actor(actor_id: String) -> void:
	if not actors.erase(actor_id):
		return
	actor_removed.emit(actor_id)
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
