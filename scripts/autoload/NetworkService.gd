extends Node
class_name NetworkServiceSingleton
## Owns Godot 4 network lifecycle and exposes intent-level signals for the MVP core.

signal status_changed(status: String)
signal server_started(port: int)
signal client_connected()
signal client_disconnected()
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal join_accepted(payload: Dictionary)
signal network_error(message: String)
signal intent_submitted(message_type: String, payload: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal actor_moved_received(payload: Dictionary)
signal move_rejected(payload: Dictionary)
signal chat_message_received(payload: Dictionary)
signal system_message_received(payload: Dictionary)
signal roll_result_received(payload: Dictionary)

const NPC_TYPES := {
	"goblin": {
		"name": "Goblin",
		"sprite": MvpConstants.SPRITE_NPC_GOBLIN,
		"ap": 6,
		"max_ap": 6,
		"blocks_tile": true,
	},
	"raider": {
		"name": "Raider",
		"sprite": MvpConstants.SPRITE_NPC_RAIDER,
		"ap": 6,
		"max_ap": 6,
		"blocks_tile": true,
	},
	"guard": {
		"name": "Guard",
		"sprite": MvpConstants.SPRITE_NPC_GUARD,
		"ap": 6,
		"max_ap": 6,
		"blocks_tile": true,
	},
	"merchant": {
		"name": "Merchant",
		"sprite": MvpConstants.SPRITE_NPC_MERCHANT,
		"ap": 6,
		"max_ap": 6,
		"blocks_tile": true,
	},
}

var is_server := false
var is_connected := false
var local_peer_id := 0
var last_error := ""
var server_address := ""
var server_port := MvpConstants.DEFAULT_PORT
var player_name := ""
var client_id := ""
var players_by_peer_id := {}
var client_move_seq := 0
var moving_actor_ids := {}
var client_visual_moving_actor_ids := {}


func start_server(port: int) -> bool:
	_disconnect_peer()
	client_id = _load_or_create_client_id()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MvpConstants.MAX_PLAYERS)
	if error != OK:
		_set_error("Failed to start server on port %d." % port)
		return false
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	players_by_peer_id.clear()
	server_port = port
	var host_name := _normalize_player_name(player_name)
	if host_name == "Player":
		host_name = "Host"
	_prepare_server_session(host_name)
	_connect_multiplayer_signals()
	_emit_status("server started on port %d" % port)
	server_started.emit(port)
	s2c_state_snapshot(SessionState.serialize_snapshot())
	return true


func connect_to_server(address: String, port: int, name: String) -> bool:
	_disconnect_peer()
	client_id = _load_or_create_client_id()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_set_error("Failed to connect to %s:%d." % [address, port])
		return false
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_connected = false
	local_peer_id = multiplayer.get_unique_id()
	server_address = address
	server_port = port
	player_name = _normalize_player_name(name)
	_connect_multiplayer_signals()
	_emit_status("connecting to %s:%d" % [address, port])
	return true


func disconnect_from_network() -> void:
	_disconnect_peer()
	client_disconnected.emit()
	_emit_status("disconnected")


func disconnect_from_session() -> void:
	disconnect_from_network()


func is_network_server() -> bool:
	return is_server


func get_unique_peer_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return local_peer_id


func send_intent(message_type: String, payload: Dictionary = {}) -> void:
	intent_submitted.emit(message_type, payload.duplicate(true))


func receive_server_snapshot(snapshot: Dictionary) -> void:
	SessionState.apply_snapshot(snapshot)
	snapshot_received.emit(snapshot.duplicate(true))


func request_move(actor_id: String, to_tile: Vector2i) -> bool:
	if not SessionState.is_network_mode:
		print("move request ignored: not in network mode")
		return false
	if actor_id.is_empty():
		print("move request ignored: no actor selected")
		return false
	if is_client_actor_visual_moving(actor_id):
		print("move request ignored: actor is visually moving: %s" % actor_id)
		return false
	client_move_seq += 1
	var payload: Dictionary = {
		"actor_id": actor_id,
		"to_tile": to_tile,
		"client_seq": client_move_seq,
	}
	print("move request: actor=%s to_tile=%s seq=%d" % [actor_id, str(to_tile), client_move_seq])
	if is_network_server():
		c2s_move_request(payload)
	else:
		c2s_move_request.rpc_id(1, payload)
	return true


func set_client_actor_visual_moving(actor_id: String, moving: bool) -> void:
	if actor_id.is_empty():
		return
	if moving:
		client_visual_moving_actor_ids[actor_id] = true
	else:
		client_visual_moving_actor_ids.erase(actor_id)


func is_client_actor_visual_moving(actor_id: String) -> bool:
	return client_visual_moving_actor_ids.has(actor_id)


func request_chat_message(message: String) -> bool:
	var clean_message: String = _sanitize_chat_message(message)
	if clean_message.is_empty():
		print("chat ignored: empty message")
		return false
	if not SessionState.is_network_mode:
		var payload: Dictionary = _system_payload("chat requires network session")
		system_message_received.emit(payload)
		return false
	if is_network_server():
		c2s_chat_send(clean_message)
	else:
		c2s_chat_send.rpc_id(1, clean_message)
	return true


func request_roll(expr: String) -> bool:
	var clean_expr: String = expr.strip_edges()
	if clean_expr.is_empty():
		print("roll ignored: empty expression")
		return false
	if not SessionState.is_network_mode:
		var payload: Dictionary = _system_payload("roll requires network session")
		system_message_received.emit(payload)
		return false
	var request_payload: Dictionary = {
		"expr": clean_expr,
		"visibility": "public",
	}
	if is_network_server():
		c2s_roll_request(request_payload)
	else:
		c2s_roll_request.rpc_id(1, request_payload)
	return true


func request_gm_spawn_npc(npc_type: String, npc_name: String, tile: Vector2i) -> bool:
	if not SessionState.is_network_mode:
		print("spawn npc request ignored: not in network mode")
		return false
	var payload: Dictionary = {
		"npc_type": _normalize_npc_type(npc_type),
		"npc_name": npc_name.strip_edges().substr(0, MvpConstants.MAX_NAME_LENGTH),
		"tile": tile,
	}
	print("spawn npc request: type=%s name=%s tile=%s" % [
		str(payload.get("npc_type", "")),
		str(payload.get("npc_name", "")),
		str(tile),
	])
	if is_network_server():
		c2s_gm_spawn_npc(payload)
	else:
		c2s_gm_spawn_npc.rpc_id(1, payload)
	return true


func request_gm_delete_actor(actor_id: String) -> bool:
	var actor_ids: Array[String] = [actor_id]
	return request_gm_delete_actors(actor_ids)


func request_gm_delete_actors(actor_ids: Array[String]) -> bool:
	if not SessionState.is_network_mode:
		print("delete actor request ignored: not in network mode")
		return false
	var normalized_actor_ids: Array[String] = []
	for actor_id in actor_ids:
		var normalized_actor_id: String = actor_id.strip_edges()
		if normalized_actor_id.is_empty() or normalized_actor_ids.has(normalized_actor_id):
			continue
		normalized_actor_ids.append(normalized_actor_id)
	if normalized_actor_ids.is_empty():
		print("delete actor request ignored: no actor selected")
		return false
	var payload: Dictionary = {
		"actor_ids": normalized_actor_ids,
	}
	print("delete actor request: actors=%s" % str(normalized_actor_ids))
	if is_network_server():
		c2s_gm_delete_actors(payload)
	else:
		c2s_gm_delete_actors.rpc_id(1, payload)
	return true


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _disconnect_peer() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_server = false
	is_connected = false
	local_peer_id = 0
	players_by_peer_id.clear()
	client_move_seq = 0
	moving_actor_ids.clear()
	client_visual_moving_actor_ids.clear()


func _on_peer_connected(peer_id: int) -> void:
	print("peer connected: ", peer_id)
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("peer disconnected: ", peer_id)
	players_by_peer_id.erase(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	_emit_status("connected")
	client_connected.emit()
	c2s_join_request.rpc_id(1, {
		"name": player_name,
		"client_id": client_id,
	})


func _on_connection_failed() -> void:
	_set_error("Connection failed.")
	_disconnect_peer()


func _on_server_disconnected() -> void:
	_disconnect_peer()
	client_disconnected.emit()
	_emit_status("disconnected")


func _set_error(message: String) -> void:
	last_error = message
	print(message)
	network_error.emit(message)
	status_changed.emit(message)


func _emit_status(status: String) -> void:
	print(status)
	status_changed.emit(status)


func _normalize_player_name(name: String) -> String:
	var normalized := name.strip_edges()
	if normalized.is_empty():
		normalized = "Player"
	return normalized.substr(0, MvpConstants.MAX_NAME_LENGTH)


func _load_or_create_client_id() -> String:
	if not client_id.is_empty():
		return client_id
	if FileAccess.file_exists(MvpConstants.CLIENT_IDENTITY_PATH):
		var file: FileAccess = FileAccess.open(MvpConstants.CLIENT_IDENTITY_PATH, FileAccess.READ)
		if file != null:
			var parsed_data: Variant = JSON.parse_string(file.get_as_text())
			if parsed_data is Dictionary:
				var stored_client_id: String = _normalize_client_id(str((parsed_data as Dictionary).get("client_id", "")))
				if not stored_client_id.is_empty():
					client_id = stored_client_id
					return client_id
	client_id = _generate_client_id()
	_save_client_identity(client_id)
	return client_id


func _save_client_identity(identity_client_id: String) -> void:
	var file: FileAccess = FileAccess.open(MvpConstants.CLIENT_IDENTITY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save client identity.")
		return
	file.store_string(JSON.stringify({"client_id": identity_client_id}, "\t"))


func _generate_client_id() -> String:
	randomize()
	var tail: String = "%04x%08x" % [randi() % 65536, randi()]
	return "%08x-%04x-%04x-%04x-%s" % [
		randi(),
		randi() % 65536,
		randi() % 65536,
		randi() % 65536,
		tail,
	]


func _normalize_client_id(identity_client_id: String) -> String:
	var normalized_client_id: String = identity_client_id.strip_edges()
	normalized_client_id = normalized_client_id.replace("\r", "")
	normalized_client_id = normalized_client_id.replace("\n", "")
	if normalized_client_id.length() > 96:
		normalized_client_id = normalized_client_id.substr(0, 96)
	return normalized_client_id


func _owner_key_from_client_id(peer_id: int, identity_client_id: String) -> String:
	var normalized_client_id: String = _normalize_client_id(identity_client_id)
	if normalized_client_id.is_empty():
		return "peer_%d" % peer_id
	return normalized_client_id


func _build_join_payload(peer_id: int, name: String, role: String, owner_key: String = "", character_id: String = "") -> Dictionary:
	var player_id := "player_%d" % peer_id
	var actor_id := "actor_peer_%d" % peer_id
	return {
		"peer_id": peer_id,
		"name": _normalize_player_name(name),
		"role": role,
		"player_id": player_id,
		"actor_id": actor_id,
		"owner_key": owner_key,
		"character_id": character_id,
	}


func _prepare_server_session(host_name: String) -> void:
	SessionState.reset_all()
	SessionState.is_network_mode = true
	SessionState.local_peer_id = local_peer_id
	SessionState.local_role = MvpConstants.ROLE_GM
	var host_owner_key: String = _owner_key_from_client_id(local_peer_id, client_id)
	var host_character: Dictionary = CharacterService.get_or_create_character_for_owner(host_owner_key, host_name, "human")
	var host_character_id: String = str(host_character.get("character_id", ""))
	var host_spawn_tile: Vector2i = _get_character_spawn_tile(host_character, Vector2i(-2, 7))
	var host_actor: Dictionary = CharacterService.character_to_actor(host_character, local_peer_id, host_spawn_tile)
	var host_actor_id: String = str(host_actor.get(EntityData.ACTOR_ID, "actor_peer_%d" % local_peer_id))
	var host_display_name: String = str(host_actor.get(EntityData.NAME, host_name))
	var host_player: Dictionary = SessionState.create_player(local_peer_id, host_display_name, MvpConstants.ROLE_GM, host_actor_id, host_owner_key, host_character_id)
	SessionState.local_player_id = str(host_player.get(EntityData.PLAYER_ID, ""))
	SessionState.local_owner_key = host_owner_key
	SessionState.local_character_id = host_character_id
	SessionState.set_local_character(host_character)
	SessionState.local_actor_id = host_actor_id
	SessionState.selected_actor_id = host_actor_id
	SessionState.set_actor(host_actor)
	SessionState.create_actor("actor_npc_goblin_1", MvpConstants.ACTOR_KIND_NPC, "Goblin", Vector2i(-5, 7), "npc", true, 0)
	var accepted: Dictionary = {
		"peer_id": local_peer_id,
		"name": host_display_name,
		"role": MvpConstants.ROLE_GM,
		"player_id": SessionState.local_player_id,
		"actor_id": host_actor_id,
		"owner_key": host_owner_key,
		"character_id": host_character_id,
		"character": host_character.duplicate(true),
	}
	players_by_peer_id[local_peer_id] = accepted.duplicate(true)


func _create_joined_player(peer_id: int, name: String, role: String, owner_key: String) -> Dictionary:
	var character: Dictionary = CharacterService.get_or_create_character_for_owner(owner_key, name, "human")
	var character_id: String = str(character.get("character_id", ""))
	var spawn_tile: Vector2i = _get_character_spawn_tile(character, _get_player_spawn_tile())
	var actor: Dictionary = CharacterService.character_to_actor(character, peer_id, spawn_tile)
	var actor_id: String = str(actor.get(EntityData.ACTOR_ID, "actor_peer_%d" % peer_id))
	var display_name: String = str(actor.get(EntityData.NAME, name))
	var player: Dictionary = SessionState.create_player(peer_id, display_name, role, actor_id, owner_key, character_id)
	SessionState.set_actor(actor)
	return {
		"peer_id": peer_id,
		"name": display_name,
		"role": role,
		"player_id": str(player.get(EntityData.PLAYER_ID, "player_%d" % peer_id)),
		"actor_id": actor_id,
		"owner_key": owner_key,
		"character_id": character_id,
		"character": character.duplicate(true),
	}


func _get_player_spawn_tile() -> Vector2i:
	var candidates := [
		Vector2i(-3, 7),
		Vector2i(-4, 7),
		Vector2i(-3, 6),
		Vector2i(-4, 6),
		Vector2i(-6, 7),
		Vector2i(-6, 6),
	]
	for tile in candidates:
		if TileRules.is_walkable(tile) and not TileRules.is_occupied(tile):
			return tile
	return Vector2i(-3, 7)


func _get_character_spawn_tile(character: Dictionary, fallback_tile: Vector2i) -> Vector2i:
	var last_tile: Vector2i = _as_vector2i(character.get("last_tile", fallback_tile))
	if TileRules.is_walkable(last_tile) and not TileRules.is_occupied(last_tile):
		return last_tile
	if TileRules.is_walkable(fallback_tile) and not TileRules.is_occupied(fallback_tile):
		return fallback_tile
	return _get_player_spawn_tile()


func _broadcast_snapshot() -> void:
	var snapshot: Dictionary = SessionState.serialize_snapshot()
	print("broadcast snapshot: actors=%d players=%d" % [SessionState.get_actors().size(), SessionState.get_players().size()])
	s2c_state_snapshot(snapshot)
	for peer_id in players_by_peer_id.keys():
		var target_peer_id := int(peer_id)
		if target_peer_id == local_peer_id:
			continue
		s2c_state_snapshot.rpc_id(target_peer_id, snapshot)


func _broadcast_actor_moved(payload: Dictionary) -> void:
	print("broadcast actor moved: actor=%s from=%s to=%s" % [
		str(payload.get("actor_id", "")),
		str(payload.get("from_tile", Vector2i.ZERO)),
		str(payload.get("to_tile", Vector2i.ZERO)),
	])
	s2c_actor_moved(payload)
	for peer_id in players_by_peer_id.keys():
		var target_peer_id := int(peer_id)
		if target_peer_id == local_peer_id:
			continue
		s2c_actor_moved.rpc_id(target_peer_id, payload)


func _broadcast_chat_message(payload: Dictionary) -> void:
	print("broadcast chat message: peer=%d name=%s message=%s" % [
		int(payload.get("peer_id", 0)),
		str(payload.get("name", "")),
		str(payload.get("message", "")),
	])
	s2c_chat_message(payload)
	for peer_id in players_by_peer_id.keys():
		var target_peer_id := int(peer_id)
		if target_peer_id == local_peer_id:
			continue
		s2c_chat_message.rpc_id(target_peer_id, payload)


func _broadcast_roll_result(payload: Dictionary) -> void:
	print("broadcast roll result: peer=%d name=%s expr=%s total=%d" % [
		int(payload.get("peer_id", 0)),
		str(payload.get("name", "")),
		str(payload.get("normalized_expr", "")),
		int(payload.get("total", 0)),
	])
	s2c_roll_result(payload)
	for peer_id in players_by_peer_id.keys():
		var target_peer_id := int(peer_id)
		if target_peer_id == local_peer_id:
			continue
		s2c_roll_result.rpc_id(target_peer_id, payload)


func _send_system_message(peer_id: int, text: String) -> void:
	if peer_id == local_peer_id:
		s2c_system_message(text)
	else:
		s2c_system_message.rpc_id(peer_id, text)


func _send_move_rejected(peer_id: int, payload: Dictionary) -> void:
	print("move rejected: peer=%d actor=%s reason_code=%s reason=%s" % [
		peer_id,
		str(payload.get("actor_id", "")),
		str(payload.get("reason_code", "")),
		str(payload.get("reason", "unknown")),
	])
	if peer_id == local_peer_id:
		s2c_move_rejected(payload)
	else:
		s2c_move_rejected.rpc_id(peer_id, payload)


func _send_chat_rejected(peer_id: int, reason: String) -> void:
	print("chat rejected: peer=%d reason=%s" % [peer_id, reason])
	_send_system_message(peer_id, "chat rejected: %s" % reason)


func _send_roll_rejected(peer_id: int, reason: String) -> void:
	print("roll rejected: peer=%d reason=%s" % [peer_id, reason])
	_send_system_message(peer_id, "Roll rejected: %s" % reason)


func _send_spawn_rejected(peer_id: int, reason: String) -> void:
	print("spawn rejected: peer=%d reason=%s" % [peer_id, reason])
	_send_system_message(peer_id, "Spawn rejected: %s" % reason)


func _send_delete_rejected(peer_id: int, reason: String) -> void:
	print("delete rejected: peer=%d reason=%s" % [peer_id, reason])
	_send_system_message(peer_id, "Delete rejected: %s" % reason)


func _lock_actor_movement(actor_id: String, step_count: int) -> void:
	if actor_id.is_empty():
		return
	var duration: float = _movement_lock_duration(step_count)
	var expires_at_msec: int = Time.get_ticks_msec() + int(duration * 1000.0)
	moving_actor_ids[actor_id] = expires_at_msec
	print("movement lock acquired: actor=%s steps=%d duration=%.2f" % [actor_id, step_count, duration])
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(_clear_actor_movement_lock.bind(actor_id, expires_at_msec))


func _clear_actor_movement_lock(actor_id: String, expected_expires_at_msec: int) -> void:
	if not moving_actor_ids.has(actor_id):
		return
	if int(moving_actor_ids.get(actor_id, 0)) != expected_expires_at_msec:
		return
	moving_actor_ids.erase(actor_id)
	print("movement lock released: actor=%s" % actor_id)


func _movement_lock_duration(step_count: int) -> float:
	return max(
		float(step_count) * MvpConstants.MOVE_STEP_SECONDS + MvpConstants.MOVE_LOCK_GRACE_SECONDS,
		MvpConstants.MOVE_MIN_LOCK_SECONDS
	)


func _validate_move_request(peer_id: int, actor_id: String, to_tile: Vector2i) -> Dictionary:
	var actor: Dictionary = SessionState.get_actor(actor_id)
	var authoritative_tile: Vector2i = _actor_tile(actor)
	if SessionState.get_player(peer_id).is_empty():
		return _move_validation(false, MvpConstants.MOVE_REJECT_PEER_NOT_REGISTERED, authoritative_tile)
	if actor_id.is_empty():
		return _move_validation(false, MvpConstants.MOVE_REJECT_ACTOR_ID_EMPTY, authoritative_tile)
	if actor.is_empty():
		return _move_validation(false, MvpConstants.MOVE_REJECT_ACTOR_NOT_FOUND, authoritative_tile)
	var owner_peer_id := int(actor.get(EntityData.OWNER_PEER_ID, 0))
	if owner_peer_id != peer_id and not SessionState.is_gm(peer_id):
		return _move_validation(false, MvpConstants.MOVE_REJECT_NOT_ACTOR_OWNER, authoritative_tile)
	if moving_actor_ids.has(actor_id):
		return _move_validation(false, MvpConstants.MOVE_REJECT_ACTOR_ALREADY_MOVING, authoritative_tile, false)
	var from_tile: Vector2i = authoritative_tile
	if not TileRules.has_tile(to_tile):
		return _move_validation(false, MvpConstants.MOVE_REJECT_TILE_MISSING, authoritative_tile)
	if not TileRules.is_walkable(to_tile):
		return _move_validation(false, MvpConstants.MOVE_REJECT_TILE_NOT_WALKABLE, authoritative_tile)
	if TileRules.is_occupied(to_tile, actor_id):
		return _move_validation(false, MvpConstants.MOVE_REJECT_TILE_OCCUPIED, authoritative_tile)
	var path: Array = TileRules.find_path(from_tile, to_tile, actor_id)
	if path.size() < 2:
		return _move_validation(false, MvpConstants.MOVE_REJECT_NO_PATH, authoritative_tile)
	return {
		"ok": true,
		"reason": "",
		"reason_code": "",
		"from_tile": from_tile,
		"authoritative_tile": authoritative_tile,
		"path": path,
		"cost": TileRules.path_cost(path),
	}


func _move_validation(ok: bool, reason_code: String, authoritative_tile: Vector2i, snap_to_authoritative: bool = true) -> Dictionary:
	var canonical_reason_code: String = _canonical_move_reject_code(reason_code)
	return {
		"ok": ok,
		"reason": _move_reject_reason(canonical_reason_code),
		"reason_code": canonical_reason_code,
		"authoritative_tile": authoritative_tile,
		"snap_to_authoritative": snap_to_authoritative,
	}


func _canonical_move_reject_code(reason_code: String) -> String:
	match reason_code:
		MvpConstants.MOVE_REJECT_PEER_NOT_REGISTERED, MvpConstants.MOVE_REJECT_ACTOR_ID_EMPTY:
			return "invalid_request"
		MvpConstants.MOVE_REJECT_ACTOR_NOT_FOUND:
			return "actor_not_found"
		MvpConstants.MOVE_REJECT_NOT_ACTOR_OWNER:
			return "not_your_actor"
		MvpConstants.MOVE_REJECT_ACTOR_ALREADY_MOVING:
			return "actor_already_moving"
		MvpConstants.MOVE_REJECT_TILE_MISSING:
			return "tile_does_not_exist"
		MvpConstants.MOVE_REJECT_TILE_NOT_WALKABLE:
			return "tile_not_walkable"
		MvpConstants.MOVE_REJECT_TILE_OCCUPIED:
			return "tile_occupied"
		MvpConstants.MOVE_REJECT_NO_PATH:
			return "no_path_found"
	return "invalid_request"


func _move_reject_reason(reason_code: String) -> String:
	match reason_code:
		"invalid_request":
			return "invalid move request"
		"actor_not_found":
			return "actor does not exist"
		"not_your_actor":
			return "peer does not own actor"
		"actor_already_moving":
			return "actor is already moving"
		"tile_does_not_exist":
			return "tile does not exist"
		"tile_not_walkable":
			return "tile is not walkable"
		"tile_occupied":
			return "tile is occupied"
		"no_path_found":
			return "no path to tile"
	return "move rejected"


func _actor_tile(actor: Dictionary) -> Vector2i:
	if actor.is_empty():
		return Vector2i.ZERO
	return _as_vector2i(actor.get(EntityData.TILE, Vector2i.ZERO))


func _as_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _as_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw_item in value:
			var item: String = str(raw_item).strip_edges()
			if item.is_empty() or result.has(item):
				continue
			result.append(item)
		return result
	var single_item: String = str(value).strip_edges()
	if not single_item.is_empty():
		result.append(single_item)
	return result


func _sanitize_chat_message(message: String) -> String:
	var clean_message: String = message.strip_edges()
	clean_message = clean_message.replace("\r", " ")
	clean_message = clean_message.replace("\n", " ")
	while clean_message.contains("  "):
		clean_message = clean_message.replace("  ", " ")
	if clean_message.length() > MvpConstants.MAX_CHAT_LENGTH:
		clean_message = clean_message.substr(0, MvpConstants.MAX_CHAT_LENGTH)
	return clean_message


func _handle_chat_command(peer_id: int, message: String) -> bool:
	if not message.begins_with("/"):
		return false
	var command: String = message
	var args: String = ""
	var split_index: int = message.find(" ")
	if split_index != -1:
		command = message.substr(0, split_index)
		args = message.substr(split_index + 1).strip_edges()
	command = command.to_lower()
	match command:
		"/roll", "/r":
			_handle_roll_request(peer_id, args)
			return true
		_:
			_send_system_message(peer_id, "Unknown command")
			return true


func _handle_roll_request(peer_id: int, expr: String) -> void:
	var player: Dictionary = SessionState.get_player(peer_id)
	if player.is_empty():
		_send_roll_rejected(peer_id, "peer is not registered")
		return
	var result: Dictionary = DiceRoller.roll_expression(expr, str(player.get(EntityData.PLAYER_ID, "")))
	if not bool(result.get("ok", false)):
		_send_roll_rejected(peer_id, str(result.get("error", "invalid expression")))
		return
	var payload: Dictionary = {
		"kind": "roll",
		"peer_id": peer_id,
		"player_id": str(player.get(EntityData.PLAYER_ID, "")),
		"name": str(player.get(EntityData.NAME, "Player")),
		"role": str(player.get(EntityData.ROLE, MvpConstants.ROLE_PLAYER)),
		"expr": expr.strip_edges(),
		"normalized_expr": str(result.get("normalized_expr", "")),
		"rolls": result.get("rolls", []),
		"modifier": int(result.get("modifier", 0)),
		"total": int(result.get("total", 0)),
		"server_time": Time.get_unix_time_from_system(),
	}
	_broadcast_roll_result(payload)


func _normalize_npc_type(npc_type: String) -> String:
	var normalized: String = npc_type.strip_edges().to_lower()
	if normalized.is_empty():
		normalized = "goblin"
	return normalized


func _normalize_actor_name(actor_name: String, fallback: String) -> String:
	var normalized: String = actor_name.strip_edges()
	if normalized.is_empty():
		normalized = fallback
	return normalized.substr(0, MvpConstants.MAX_NAME_LENGTH)


func _validate_gm_spawn_request(peer_id: int, npc_type: String, tile: Vector2i) -> Dictionary:
	var player: Dictionary = SessionState.get_player(peer_id)
	if player.is_empty() or str(player.get(EntityData.ROLE, "")) != MvpConstants.ROLE_GM:
		return {"ok": false, "reason": "gm role required"}
	if not NPC_TYPES.has(npc_type):
		return {"ok": false, "reason": "invalid npc type"}
	if not TileRules.has_tile(tile):
		return {"ok": false, "reason": "tile does not exist"}
	if not TileRules.is_walkable(tile):
		return {"ok": false, "reason": "tile not walkable"}
	if TileRules.is_occupied(tile):
		return {"ok": false, "reason": "tile occupied"}
	return {"ok": true, "reason": ""}


func _validate_gm_delete_request(peer_id: int, actor_id: String) -> Dictionary:
	var actor_ids: Array[String] = [actor_id]
	return _validate_gm_delete_requests(peer_id, actor_ids)


func _validate_gm_delete_requests(peer_id: int, actor_ids: Array[String]) -> Dictionary:
	var player: Dictionary = SessionState.get_player(peer_id)
	if player.is_empty() or str(player.get(EntityData.ROLE, "")) != MvpConstants.ROLE_GM:
		return {"ok": false, "reason": "gm role required"}
	if actor_ids.is_empty():
		return {"ok": false, "reason": "actor not found"}
	var actors_to_delete: Array[Dictionary] = []
	for actor_id in actor_ids:
		if actor_id.is_empty() or not SessionState.has_actor(actor_id):
			return {"ok": false, "reason": "actor not found"}
		var actor: Dictionary = SessionState.get_actor(actor_id)
		if str(actor.get(EntityData.KIND, "")) != MvpConstants.ACTOR_KIND_NPC:
			return {"ok": false, "reason": "cannot delete player actor"}
		if moving_actor_ids.has(actor_id):
			return {"ok": false, "reason": "actor is moving"}
		actors_to_delete.append(actor)
	return {"ok": true, "reason": "", "actors": actors_to_delete}


func _system_payload(text: String) -> Dictionary:
	return {
		"kind": "system",
		"message": text,
		"server_time": Time.get_unix_time_from_system(),
	}


@rpc("any_peer", "reliable")
func c2s_join_request(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var name := _normalize_player_name(str(payload.get("name", "")))
	var owner_key: String = _owner_key_from_client_id(peer_id, str(payload.get("client_id", "")))
	var role := MvpConstants.ROLE_GM if peer_id == local_peer_id else MvpConstants.ROLE_PLAYER
	var accepted := _create_joined_player(peer_id, name, role, owner_key)
	players_by_peer_id[peer_id] = accepted.duplicate(true)
	print("join request received: peer=%d name=%s role=%s owner=%s character=%s" % [
		peer_id,
		name,
		role,
		owner_key,
		str(accepted.get("character_id", "")),
	])
	if peer_id == local_peer_id:
		s2c_join_accepted(accepted)
		s2c_state_snapshot(SessionState.serialize_snapshot())
	else:
		s2c_join_accepted.rpc_id(peer_id, accepted)
		_send_system_message(peer_id, "join accepted")
	_broadcast_snapshot()


@rpc("any_peer", "reliable")
func c2s_chat_send(message: String) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var clean_message: String = _sanitize_chat_message(message)
	if clean_message.is_empty():
		_send_chat_rejected(peer_id, "empty message")
		return
	if _handle_chat_command(peer_id, clean_message):
		return
	var player: Dictionary = SessionState.get_player(peer_id)
	if player.is_empty():
		_send_chat_rejected(peer_id, "peer is not registered")
		return
	var payload: Dictionary = {
		"kind": "player",
		"peer_id": peer_id,
		"player_id": str(player.get(EntityData.PLAYER_ID, "")),
		"name": str(player.get(EntityData.NAME, "Player")),
		"role": str(player.get(EntityData.ROLE, MvpConstants.ROLE_PLAYER)),
		"message": clean_message,
		"server_time": Time.get_unix_time_from_system(),
	}
	print("chat received: peer=%d name=%s message=%s" % [
		peer_id,
		str(payload.get("name", "")),
		clean_message,
	])
	_broadcast_chat_message(payload)


@rpc("any_peer", "reliable")
func c2s_roll_request(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var expr: String = str(payload.get("expr", ""))
	print("roll request received: peer=%d expr=%s" % [peer_id, expr])
	_handle_roll_request(peer_id, expr)


@rpc("any_peer", "reliable")
func c2s_move_request(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var actor_id := str(payload.get("actor_id", ""))
	var to_tile: Vector2i = _as_vector2i(payload.get("to_tile", Vector2i.ZERO))
	var client_seq := int(payload.get("client_seq", 0))
	print("move request received: peer=%d actor=%s to_tile=%s seq=%d" % [
		peer_id,
		actor_id,
		str(to_tile),
		client_seq,
	])
	var validation: Dictionary = _validate_move_request(peer_id, actor_id, to_tile)
	if not bool(validation.get("ok", false)):
		_send_move_rejected(peer_id, {
			"actor_id": actor_id,
			"reason": str(validation.get("reason", "move rejected")),
			"reason_code": str(validation.get("reason_code", "")),
			"authoritative_tile": validation.get("authoritative_tile", Vector2i.ZERO),
			"snap_to_authoritative": bool(validation.get("snap_to_authoritative", true)),
			"client_seq": client_seq,
		})
		return
	var from_tile: Vector2i = _as_vector2i(validation.get("from_tile", Vector2i.ZERO))
	var path: Array = validation.get("path", [from_tile, to_tile])
	var cost: int = int(validation.get("cost", max(path.size() - 1, 0)))
	SessionState.move_actor(actor_id, to_tile, false)
	_lock_actor_movement(actor_id, cost)
	_broadcast_actor_moved({
		"actor_id": actor_id,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"path": path,
		"cost": cost,
		"client_seq": client_seq,
	})


@rpc("any_peer", "reliable")
func c2s_gm_spawn_npc(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var npc_type: String = _normalize_npc_type(str(payload.get("npc_type", "")))
	var tile: Vector2i = _as_vector2i(payload.get("tile", Vector2i.ZERO))
	print("spawn npc request received: peer=%d type=%s tile=%s" % [
		peer_id,
		npc_type,
		str(tile),
	])
	var validation: Dictionary = _validate_gm_spawn_request(peer_id, npc_type, tile)
	if not bool(validation.get("ok", false)):
		_send_spawn_rejected(peer_id, str(validation.get("reason", "invalid request")))
		return
	var template: Dictionary = NPC_TYPES.get(npc_type, {}) as Dictionary
	var npc_name: String = _normalize_actor_name(str(payload.get("npc_name", "")), str(template.get("name", "NPC")))
	var actor: Dictionary = SessionState.create_npc_actor(npc_type, npc_name, tile, template)
	if actor.is_empty():
		_send_spawn_rejected(peer_id, "invalid request")
		return
	print("npc spawned: peer=%d actor=%s name=%s tile=%s" % [
		peer_id,
		str(actor.get(EntityData.ACTOR_ID, "")),
		str(actor.get(EntityData.NAME, "")),
		str(tile),
	])
	_send_system_message(peer_id, "Spawned %s at %s" % [str(actor.get(EntityData.NAME, "NPC")), str(tile)])
	_broadcast_snapshot()


@rpc("any_peer", "reliable")
func c2s_gm_delete_actor(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var actor_id: String = str(payload.get("actor_id", "")).strip_edges()
	var actor_ids: Array[String] = [actor_id]
	_handle_gm_delete_actors(peer_id, actor_ids)


@rpc("any_peer", "reliable")
func c2s_gm_delete_actors(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var actor_ids: Array[String] = _as_string_array(payload.get("actor_ids", []))
	_handle_gm_delete_actors(peer_id, actor_ids)


func _handle_gm_delete_actors(peer_id: int, actor_ids: Array[String]) -> void:
	print("delete actors request received: peer=%d actors=%s" % [peer_id, str(actor_ids)])
	var validation: Dictionary = _validate_gm_delete_requests(peer_id, actor_ids)
	if not bool(validation.get("ok", false)):
		_send_delete_rejected(peer_id, str(validation.get("reason", "invalid request")))
		return
	var actors: Array = validation.get("actors", [])
	var deleted_names: Array[String] = []
	for raw_actor in actors:
		var actor: Dictionary = raw_actor as Dictionary
		var actor_id: String = str(actor.get(EntityData.ACTOR_ID, ""))
		if actor_id.is_empty():
			continue
		deleted_names.append(str(actor.get(EntityData.NAME, actor_id)))
		SessionState.remove_actor(actor_id)
	print("actors deleted: peer=%d count=%d names=%s" % [peer_id, deleted_names.size(), str(deleted_names)])
	if deleted_names.size() == 1:
		_send_system_message(peer_id, "Deleted %s" % deleted_names[0])
	else:
		_send_system_message(peer_id, "Deleted %d actors" % deleted_names.size())
	_broadcast_snapshot()


@rpc("authority", "reliable")
func s2c_join_accepted(payload: Dictionary) -> void:
	local_peer_id = int(payload.get("peer_id", local_peer_id))
	SessionState.is_network_mode = true
	SessionState.local_peer_id = local_peer_id
	SessionState.local_player_id = str(payload.get("player_id", ""))
	SessionState.local_owner_key = str(payload.get("owner_key", ""))
	SessionState.local_character_id = str(payload.get("character_id", ""))
	var raw_character_payload: Variant = payload.get("character", {})
	if raw_character_payload is Dictionary:
		var character_payload: Dictionary = raw_character_payload as Dictionary
		if not character_payload.is_empty():
			SessionState.set_local_character(character_payload)
	SessionState.local_role = str(payload.get("role", ""))
	SessionState.local_actor_id = str(payload.get("actor_id", ""))
	SessionState.selected_actor_id = SessionState.local_actor_id
	print("join accepted: ", payload)
	join_accepted.emit(payload.duplicate(true))
	_emit_status("join accepted")


@rpc("authority", "reliable")
func s2c_system_message(text: String) -> void:
	print("system: ", text)
	var payload: Dictionary = _system_payload(text)
	SessionState.add_chat_message(payload)
	system_message_received.emit(payload)


@rpc("authority", "reliable")
func s2c_chat_message(payload: Dictionary) -> void:
	print("chat message: %s: %s" % [
		str(payload.get("name", "Player")),
		str(payload.get("message", "")),
	])
	SessionState.add_chat_message(payload.duplicate(true))
	chat_message_received.emit(payload.duplicate(true))


@rpc("authority", "reliable")
func s2c_roll_result(payload: Dictionary) -> void:
	print("roll result: %s rolled %s total=%d" % [
		str(payload.get("name", "Player")),
		str(payload.get("normalized_expr", "")),
		int(payload.get("total", 0)),
	])
	SessionState.add_chat_message(payload.duplicate(true))
	roll_result_received.emit(payload.duplicate(true))


@rpc("authority", "reliable")
func s2c_state_snapshot(snapshot: Dictionary) -> void:
	var snapshot_actors := snapshot.get("actors", {}) as Dictionary
	var snapshot_players := snapshot.get("players", {}) as Dictionary
	print("state snapshot received: actors=%d players=%d" % [
		snapshot_actors.size(),
		snapshot_players.size(),
	])
	receive_server_snapshot(snapshot)


@rpc("authority", "reliable")
func s2c_actor_moved(payload: Dictionary) -> void:
	var actor_id := str(payload.get("actor_id", ""))
	var to_tile: Vector2i = _as_vector2i(payload.get("to_tile", Vector2i.ZERO))
	print("actor moved: actor=%s to_tile=%s cost=%d seq=%d" % [
		actor_id,
		str(to_tile),
		int(payload.get("cost", 0)),
		int(payload.get("client_seq", 0)),
	])
	if not actor_id.is_empty():
		SessionState.move_actor(actor_id, to_tile, false)
	actor_moved_received.emit(payload.duplicate(true))


@rpc("authority", "reliable")
func s2c_move_rejected(payload: Dictionary) -> void:
	var actor_id := str(payload.get("actor_id", ""))
	var authoritative_tile: Vector2i = _as_vector2i(payload.get("authoritative_tile", Vector2i.ZERO))
	var reason := str(payload.get("reason", "move rejected"))
	var reason_code: String = str(payload.get("reason_code", ""))
	var should_snap: bool = bool(payload.get("snap_to_authoritative", true))
	if reason_code == MvpConstants.MOVE_REJECT_ACTOR_ALREADY_MOVING:
		should_snap = false
	print("move rejected: actor=%s reason_code=%s reason=%s authoritative_tile=%s snap=%s seq=%d" % [
		actor_id,
		reason_code,
		reason,
		str(authoritative_tile),
		str(should_snap),
		int(payload.get("client_seq", 0)),
	])
	if should_snap and not actor_id.is_empty() and SessionState.has_actor(actor_id):
		SessionState.move_actor(actor_id, authoritative_tile)
	move_rejected.emit(payload.duplicate(true))
