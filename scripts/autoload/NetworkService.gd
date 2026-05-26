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

var is_server := false
var is_connected := false
var local_peer_id := 0
var last_error := ""
var server_address := ""
var server_port := MvpConstants.DEFAULT_PORT
var player_name := ""
var players_by_peer_id := {}
var client_move_seq := 0


func start_server(port: int) -> bool:
	_disconnect_peer()
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


func _build_join_payload(peer_id: int, name: String, role: String) -> Dictionary:
	var player_id := "player_%d" % peer_id
	var actor_id := "actor_peer_%d" % peer_id
	return {
		"peer_id": peer_id,
		"name": _normalize_player_name(name),
		"role": role,
		"player_id": player_id,
		"actor_id": actor_id,
	}


func _prepare_server_session(host_name: String) -> void:
	SessionState.reset_all()
	SessionState.is_network_mode = true
	SessionState.local_peer_id = local_peer_id
	SessionState.local_role = MvpConstants.ROLE_GM
	var host_actor_id := "actor_peer_%d" % local_peer_id
	var host_player: Dictionary = SessionState.create_player(local_peer_id, host_name, MvpConstants.ROLE_GM, host_actor_id)
	SessionState.local_player_id = str(host_player.get(EntityData.PLAYER_ID, ""))
	SessionState.local_actor_id = host_actor_id
	SessionState.selected_actor_id = host_actor_id
	SessionState.create_actor(host_actor_id, MvpConstants.ACTOR_KIND_PLAYER, host_name, Vector2i(-2, 7), "player", true, local_peer_id)
	SessionState.create_actor("actor_npc_goblin_1", MvpConstants.ACTOR_KIND_NPC, "Goblin", Vector2i(-5, 7), "npc", true, 0)
	var accepted: Dictionary = {
		"peer_id": local_peer_id,
		"name": host_name,
		"role": MvpConstants.ROLE_GM,
		"player_id": SessionState.local_player_id,
		"actor_id": host_actor_id,
	}
	players_by_peer_id[local_peer_id] = accepted.duplicate(true)


func _create_joined_player(peer_id: int, name: String, role: String) -> Dictionary:
	var actor_id := "actor_peer_%d" % peer_id
	var player: Dictionary = SessionState.create_player(peer_id, name, role, actor_id)
	var spawn_tile := _get_player_spawn_tile()
	SessionState.create_actor(actor_id, MvpConstants.ACTOR_KIND_PLAYER, name, spawn_tile, "player", true, peer_id)
	return {
		"peer_id": peer_id,
		"name": name,
		"role": role,
		"player_id": str(player.get(EntityData.PLAYER_ID, "player_%d" % peer_id)),
		"actor_id": actor_id,
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


func _send_move_rejected(peer_id: int, payload: Dictionary) -> void:
	print("move rejected: peer=%d actor=%s reason=%s" % [
		peer_id,
		str(payload.get("actor_id", "")),
		str(payload.get("reason", "unknown")),
	])
	if peer_id == local_peer_id:
		s2c_move_rejected(payload)
	else:
		s2c_move_rejected.rpc_id(peer_id, payload)


func _validate_move_request(peer_id: int, actor_id: String, to_tile: Vector2i) -> Dictionary:
	var actor: Dictionary = SessionState.get_actor(actor_id)
	var authoritative_tile: Vector2i = _actor_tile(actor)
	if SessionState.get_player(peer_id).is_empty():
		return _move_validation(false, "peer is not registered", authoritative_tile)
	if actor_id.is_empty():
		return _move_validation(false, "actor_id is empty", authoritative_tile)
	if actor.is_empty():
		return _move_validation(false, "actor does not exist", authoritative_tile)
	var owner_peer_id := int(actor.get(EntityData.OWNER_PEER_ID, 0))
	if owner_peer_id != peer_id and not SessionState.is_gm(peer_id):
		return _move_validation(false, "peer does not own actor", authoritative_tile)
	var from_tile: Vector2i = authoritative_tile
	if not TileRules.has_tile(to_tile):
		return _move_validation(false, "tile does not exist", authoritative_tile)
	if not TileRules.is_walkable(to_tile):
		return _move_validation(false, "tile is not walkable", authoritative_tile)
	if TileRules.is_occupied(to_tile, actor_id):
		return _move_validation(false, "tile is occupied", authoritative_tile)
	var path: Array = TileRules.find_path(from_tile, to_tile, actor_id)
	if path.size() < 2:
		return _move_validation(false, "no path to tile", authoritative_tile)
	return {
		"ok": true,
		"reason": "",
		"from_tile": from_tile,
		"authoritative_tile": authoritative_tile,
		"path": path,
		"cost": TileRules.path_cost(path),
	}


func _move_validation(ok: bool, reason: String, authoritative_tile: Vector2i) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"authoritative_tile": authoritative_tile,
	}


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


@rpc("any_peer", "reliable")
func c2s_join_request(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var name := _normalize_player_name(str(payload.get("name", "")))
	var role := MvpConstants.ROLE_GM if peer_id == local_peer_id else MvpConstants.ROLE_PLAYER
	var accepted := _create_joined_player(peer_id, name, role)
	players_by_peer_id[peer_id] = accepted.duplicate(true)
	print("join request received: peer=%d name=%s role=%s" % [peer_id, name, role])
	if peer_id == local_peer_id:
		s2c_join_accepted(accepted)
		s2c_state_snapshot(SessionState.serialize_snapshot())
	else:
		s2c_join_accepted.rpc_id(peer_id, accepted)
		s2c_system_message.rpc_id(peer_id, "join accepted")
	_broadcast_snapshot()


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
			"authoritative_tile": validation.get("authoritative_tile", Vector2i.ZERO),
			"client_seq": client_seq,
		})
		return
	var from_tile: Vector2i = _as_vector2i(validation.get("from_tile", Vector2i.ZERO))
	var path: Array = validation.get("path", [from_tile, to_tile])
	var cost: int = int(validation.get("cost", max(path.size() - 1, 0)))
	SessionState.move_actor(actor_id, to_tile, false)
	_broadcast_actor_moved({
		"actor_id": actor_id,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"path": path,
		"cost": cost,
		"client_seq": client_seq,
	})


@rpc("authority", "reliable")
func s2c_join_accepted(payload: Dictionary) -> void:
	local_peer_id = int(payload.get("peer_id", local_peer_id))
	SessionState.is_network_mode = true
	SessionState.local_peer_id = local_peer_id
	SessionState.local_player_id = str(payload.get("player_id", ""))
	SessionState.local_role = str(payload.get("role", ""))
	SessionState.local_actor_id = str(payload.get("actor_id", ""))
	SessionState.selected_actor_id = SessionState.local_actor_id
	print("join accepted: ", payload)
	join_accepted.emit(payload.duplicate(true))
	_emit_status("join accepted")


@rpc("authority", "reliable")
func s2c_system_message(text: String) -> void:
	print("system: ", text)


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
	print("move rejected: actor=%s reason=%s authoritative_tile=%s seq=%d" % [
		actor_id,
		reason,
		str(authoritative_tile),
		int(payload.get("client_seq", 0)),
	])
	if not actor_id.is_empty() and SessionState.has_actor(actor_id):
		SessionState.move_actor(actor_id, authoritative_tile)
	move_rejected.emit(payload.duplicate(true))
