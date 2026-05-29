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
signal local_character_changed(character: Dictionary)
signal character_list_changed(payload: Dictionary)

var players := {}
var actors := {}
var available_characters: Array = []
var last_character_id := ""
var selected_actor_id := ""
var local_peer_id := 0
var local_player_id := ""
var local_owner_key := ""
var local_character_id := ""
var local_character: Dictionary = {}
var local_role := ""
var local_actor_id := ""
var is_network_mode := false
var is_joined := false
var is_character_selecting := false
var encounter := {}
var map_id := ""
var chat_log: Array = []
var actor_sequence := 0


func reset() -> void:
	reset_all()


func reset_all() -> void:
	players.clear()
	actors.clear()
	available_characters.clear()
	last_character_id = ""
	selected_actor_id = ""
	local_peer_id = 0
	local_player_id = ""
	local_owner_key = ""
	local_character_id = ""
	local_character.clear()
	local_role = ""
	local_actor_id = ""
	is_network_mode = false
	is_joined = false
	is_character_selecting = false
	actor_sequence = 0
	chat_log.clear()
	map_id = MvpConstants.DEFAULT_MAP_ID
	encounter = _default_encounter()
	actors_changed.emit()
	local_character_changed.emit({})
	character_list_changed.emit({})
	state_changed.emit()


func reset_local_debug_state() -> void:
	actors.clear()
	selected_actor_id = ""
	if not is_network_mode:
		players.clear()
		available_characters.clear()
		last_character_id = ""
		local_peer_id = 0
		local_player_id = ""
		local_owner_key = ""
		local_character_id = ""
		local_character.clear()
		local_role = ""
		local_actor_id = ""
		is_joined = false
		is_character_selecting = false
	map_id = MvpConstants.DEFAULT_MAP_ID
	actors_changed.emit()
	if not is_network_mode:
		local_character_changed.emit({})
		character_list_changed.emit({})
	state_changed.emit()


func apply_snapshot(snapshot: Dictionary) -> void:
	map_id = str(snapshot.get("map_id", MvpConstants.DEFAULT_MAP_ID))
	players = snapshot.get("players", {}).duplicate(true)
	actors = snapshot.get("actors", {}).duplicate(true)
	encounter = snapshot.get("encounter", _default_encounter()).duplicate(true)
	chat_log = snapshot.get("chat_log", []).duplicate(true)
	if is_network_mode and not local_actor_id.is_empty() and actors.has(local_actor_id):
		selected_actor_id = local_actor_id
	else:
		selected_actor_id = str(snapshot.get("selected_actor_id", selected_actor_id))
	actors_changed.emit()
	state_changed.emit()


func get_snapshot() -> Dictionary:
	return serialize_snapshot()


func serialize_snapshot() -> Dictionary:
	return {
		"map_id": map_id,
		"players": players.duplicate(true),
		"actors": actors.duplicate(true),
		"encounter": encounter.duplicate(true),
	}


func set_local_character(character: Dictionary) -> void:
	local_character = character.duplicate(true)
	local_character_id = str(local_character.get("character_id", local_character_id))
	local_owner_key = str(local_character.get("owner_key", local_owner_key))
	local_character_changed.emit(local_character.duplicate(true))
	state_changed.emit()


func get_local_character() -> Dictionary:
	return local_character.duplicate(true)


func set_character_list(payload: Dictionary) -> void:
	is_network_mode = true
	if not is_joined:
		is_character_selecting = true
	var raw_characters: Variant = payload.get("characters", [])
	if raw_characters is Array:
		available_characters = (raw_characters as Array).duplicate(true)
	else:
		available_characters = []
	last_character_id = str(payload.get("last_character_id", ""))
	local_owner_key = str(payload.get("owner_key", local_owner_key))
	character_list_changed.emit(payload.duplicate(true))
	state_changed.emit()


func get_available_characters() -> Array:
	return available_characters.duplicate(true)


func has_actor(actor_id: String) -> bool:
	return actors.has(actor_id)


func get_actor(actor_id: String) -> Dictionary:
	return actors.get(actor_id, {}).duplicate(true)


func create_actor(actor_id: String, kind: String, actor_name: String, tile: Vector2i, sprite := "", blocks_tile := true, owner_peer_id := 0) -> Dictionary:
	if actor_id.is_empty():
		return {}
	var actor: Dictionary = EntityData.make_actor(
		actor_id,
		kind,
		owner_peer_id,
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


func generate_actor_id(prefix: String = "actor_npc") -> String:
	actor_sequence += 1
	var candidate: String = "%s_%d" % [prefix, actor_sequence]
	while actors.has(candidate):
		actor_sequence += 1
		candidate = "%s_%d" % [prefix, actor_sequence]
	return candidate


func create_npc_actor(npc_type: String, actor_name: String, tile: Vector2i, template: Dictionary) -> Dictionary:
	var safe_type: String = npc_type.strip_edges().to_lower()
	if safe_type.is_empty():
		safe_type = "npc"
	var max_ap: int = int(template.get(EntityData.MAX_AP, template.get("max_ap", MvpConstants.DEFAULT_MAX_AP)))
	var actor: Dictionary = EntityData.make_actor(
		generate_actor_id("actor_npc_%s" % safe_type),
		MvpConstants.ACTOR_KIND_NPC,
		0,
		actor_name,
		tile,
		_resolve_actor_sprite(MvpConstants.ACTOR_KIND_NPC, str(template.get(EntityData.SPRITE, template.get("sprite", "npc")))),
		max_ap,
		bool(template.get(EntityData.BLOCKS_TILE, template.get("blocks_tile", true)))
	)
	actor[EntityData.AP] = int(template.get(EntityData.AP, template.get("ap", max_ap)))
	actors[str(actor.get(EntityData.ACTOR_ID, ""))] = actor.duplicate(true)
	actor_changed.emit(str(actor.get(EntityData.ACTOR_ID, "")))
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


func move_actor(actor_id: String, tile: Vector2i, emit_visual: bool = true) -> bool:
	if not actors.has(actor_id):
		return false
	var actor: Dictionary = actors[actor_id]
	var from_tile: Vector2i = actor.get(EntityData.TILE, Vector2i.ZERO)
	if from_tile == tile:
		return true
	actor[EntityData.TILE] = tile
	actors[actor_id] = actor
	if emit_visual:
		actor_moved.emit(actor_id, from_tile, tile)
	actor_changed.emit(actor_id)
	state_changed.emit()
	return true


func get_actors() -> Dictionary:
	return actors.duplicate(true)


func find_actor_at_tile(tile: Vector2i) -> String:
	var fallback_actor_id := ""
	for raw_actor in actors.values():
		var actor: Dictionary = raw_actor as Dictionary
		var actor_id := str(actor.get(EntityData.ACTOR_ID, ""))
		if actor_id.is_empty():
			continue
		if actor.get(EntityData.TILE, Vector2i.ZERO) != tile:
			continue
		if bool(actor.get(EntityData.BLOCKS_TILE, true)):
			return actor_id
		if fallback_actor_id.is_empty():
			fallback_actor_id = actor_id
	return fallback_actor_id


func create_player(peer_id: int, player_name: String, role: String, actor_id: String, owner_key: String = "", character_id: String = "") -> Dictionary:
	if peer_id == 0:
		return {}
	var player_id := "player_%d" % peer_id
	var player := EntityData.make_player(peer_id, player_id, player_name, role, actor_id, owner_key, character_id)
	players[peer_id] = player.duplicate(true)
	state_changed.emit()
	return player.duplicate(true)


func get_players() -> Dictionary:
	return players.duplicate(true)


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


func is_character_active(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	for raw_player in players.values():
		var player: Dictionary = raw_player as Dictionary
		if str(player.get(EntityData.CHARACTER_ID, "")) == character_id:
			return true
	return false


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
