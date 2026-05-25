extends RefCounted
class_name WorldState
## Server-owned world state container for actors, players, map id, and encounter state.

var players := {}
var actors := {}
var encounter := {}
var map_id := ""
var chat_log: Array = []


func clear() -> void:
	players.clear()
	actors.clear()
	chat_log.clear()
	map_id = MvpConstants.DEFAULT_MAP_ID
	encounter = {
		"active": false,
		"round": 0,
		"turn_index": -1,
		"initiative": [],
		"current_actor_id": "",
	}


func to_snapshot() -> Dictionary:
	return {
		"players": players.duplicate(true),
		"actors": actors.duplicate(true),
		"encounter": encounter.duplicate(true),
		"map_id": map_id,
		"chat_log": chat_log.duplicate(true),
	}


func apply_delta(delta: Dictionary) -> void:
	for key in delta.keys():
		set(key, delta[key])
