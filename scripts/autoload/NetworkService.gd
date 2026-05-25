extends Node
class_name NetworkServiceSingleton
## Owns Godot 4 network lifecycle and exposes intent-level signals for the MVP core.

signal status_changed(status: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal intent_submitted(message_type: String, payload: Dictionary)
signal snapshot_received(snapshot: Dictionary)

var is_server := false
var is_connected := false
var local_peer_id := 0
var last_error := ""
var server_address := ""
var server_port := MvpConstants.DEFAULT_PORT
var player_name := ""


func start_server(port: int) -> void:
	_disconnect_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MvpConstants.MAX_PLAYERS)
	if error != OK:
		_set_error("Failed to start server on port %d." % port)
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	server_port = port
	_connect_multiplayer_signals()
	status_changed.emit("server_started")


func connect_to_server(address: String, port: int, name: String) -> void:
	_disconnect_peer()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_set_error("Failed to connect to %s:%d." % [address, port])
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_connected = false
	local_peer_id = multiplayer.get_unique_id()
	server_address = address
	server_port = port
	player_name = name
	_connect_multiplayer_signals()
	status_changed.emit("connecting")


func disconnect_from_session() -> void:
	_disconnect_peer()
	status_changed.emit("disconnected")


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


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	is_connected = true
	local_peer_id = multiplayer.get_unique_id()
	status_changed.emit("connected")


func _on_connection_failed() -> void:
	_set_error("Connection failed.")
	_disconnect_peer()


func _on_server_disconnected() -> void:
	_disconnect_peer()
	status_changed.emit("server_disconnected")


func _set_error(message: String) -> void:
	last_error = message
	status_changed.emit(message)
