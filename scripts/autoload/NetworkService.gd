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

var is_server := false
var is_connected := false
var local_peer_id := 0
var last_error := ""
var server_address := ""
var server_port := MvpConstants.DEFAULT_PORT
var player_name := ""
var players_by_peer_id := {}


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
	players_by_peer_id[local_peer_id] = _build_join_payload(local_peer_id, "Host", MvpConstants.ROLE_GM)
	server_port = port
	_connect_multiplayer_signals()
	_emit_status("server started on port %d" % port)
	server_started.emit(port)
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
	return {
		"peer_id": peer_id,
		"name": _normalize_player_name(name),
		"role": role,
		"player_id": "player_%d" % peer_id,
	}


@rpc("any_peer", "reliable")
func c2s_join_request(payload: Dictionary) -> void:
	if not is_server:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = local_peer_id
	var name := _normalize_player_name(str(payload.get("name", "")))
	var role := MvpConstants.ROLE_GM if peer_id == local_peer_id else MvpConstants.ROLE_PLAYER
	var accepted := _build_join_payload(peer_id, name, role)
	players_by_peer_id[peer_id] = accepted.duplicate(true)
	print("join request received: peer=%d name=%s role=%s" % [peer_id, name, role])
	if peer_id == local_peer_id:
		s2c_join_accepted(accepted)
	else:
		s2c_join_accepted.rpc_id(peer_id, accepted)
		s2c_system_message.rpc_id(peer_id, "join accepted")


@rpc("authority", "reliable")
func s2c_join_accepted(payload: Dictionary) -> void:
	local_peer_id = int(payload.get("peer_id", local_peer_id))
	print("join accepted: ", payload)
	join_accepted.emit(payload.duplicate(true))
	_emit_status("join accepted")


@rpc("authority", "reliable")
func s2c_system_message(text: String) -> void:
	print("system: ", text)
