extends Node
class_name UIController
## Connects UI widgets to network intents and displays server messages.

const STATE_OFFLINE := "offline"
const STATE_HOSTING := "hosting"
const STATE_CONNECTED := "connected"
const STATE_IN_ENCOUNTER := "in_encounter"

var ui_root: Node
var connect_panel: Node
var chat_panel: Node
var dice_panel: Node
var encounter_panel: Node
var gm_panel: Node
var debug_status: Label
var roll_toast_scene := preload("res://scenes/ui/RollToast.tscn")
var ui_state := STATE_OFFLINE
var last_non_encounter_state := STATE_OFFLINE
var player_name := "-"
var player_role := "-"
var peer_id := 0


func bind_ui(root: Node) -> void:
	ui_root = root
	connect_panel = root.get_node_or_null("ConnectPanel")
	chat_panel = root.get_node_or_null("ChatPanel")
	dice_panel = root.get_node_or_null("DicePanel")
	encounter_panel = root.get_node_or_null("EncounterPanel")
	gm_panel = root.get_node_or_null("GMPanel")
	debug_status = root.get_node_or_null("DebugStatus") as Label
	_connect_network_signals()
	_set_ui_state(STATE_OFFLINE)


func show_chat_message(message: Dictionary) -> void:
	if chat_panel and chat_panel.has_method("append_message"):
		chat_panel.append_message(message)


func show_roll_result(result: Dictionary) -> void:
	if not ui_root:
		return
	var toast := roll_toast_scene.instantiate()
	ui_root.add_child(toast)
	if toast.has_method("show_result"):
		toast.show_result(result)


func show_encounter_state(state: Dictionary) -> void:
	if encounter_panel and encounter_panel.has_method("apply_encounter_state"):
		encounter_panel.apply_encounter_state(state)
	var active := bool(state.get("active", false))
	if active:
		if ui_state != STATE_IN_ENCOUNTER:
			last_non_encounter_state = ui_state
		_set_ui_state(STATE_IN_ENCOUNTER)
	else:
		_set_ui_state(last_non_encounter_state)


func _connect_network_signals() -> void:
	if not NetworkService.server_started.is_connected(_on_server_started):
		NetworkService.server_started.connect(_on_server_started)
	if not NetworkService.join_accepted.is_connected(_on_join_accepted):
		NetworkService.join_accepted.connect(_on_join_accepted)
	if not NetworkService.client_disconnected.is_connected(_on_client_disconnected):
		NetworkService.client_disconnected.connect(_on_client_disconnected)
	if not NetworkService.network_error.is_connected(_on_network_error):
		NetworkService.network_error.connect(_on_network_error)


func _set_ui_state(new_state: String) -> void:
	ui_state = new_state
	if new_state != STATE_IN_ENCOUNTER:
		last_non_encounter_state = new_state
	var connected_like := new_state == STATE_HOSTING or new_state == STATE_CONNECTED or new_state == STATE_IN_ENCOUNTER
	if connect_panel:
		connect_panel.visible = true
		if connect_panel.has_method("set_collapsed"):
			connect_panel.set_collapsed(connected_like)
	if chat_panel:
		chat_panel.visible = connected_like
	if dice_panel:
		dice_panel.visible = connected_like
	if encounter_panel:
		var encounter_visible := new_state == STATE_IN_ENCOUNTER
		if encounter_panel.has_method("set_encounter_visible"):
			encounter_panel.set_encounter_visible(encounter_visible)
		else:
			encounter_panel.visible = encounter_visible
	if gm_panel:
		var gm_visible: bool = connected_like and player_role == MvpConstants.ROLE_GM
		if gm_panel.has_method("set_gm_visible"):
			gm_panel.set_gm_visible(gm_visible)
		else:
			gm_panel.visible = gm_visible
	_update_debug_status()


func _update_debug_status() -> void:
	peer_id = NetworkService.get_unique_peer_id()
	if debug_status:
		var peer_text := "-"
		if peer_id != 0:
			peer_text = str(peer_id)
		debug_status.text = "%s | peer: %s | role: %s | name: %s" % [
			ui_state,
			peer_text,
			player_role,
			player_name,
		]


func _on_server_started(_port: int) -> void:
	var local_player := SessionState.get_player(NetworkService.get_unique_peer_id())
	player_name = str(local_player.get(EntityData.NAME, "Host"))
	player_role = str(local_player.get(EntityData.ROLE, MvpConstants.ROLE_GM))
	_set_ui_state(STATE_HOSTING)


func _on_join_accepted(payload: Dictionary) -> void:
	player_name = str(payload.get("name", "-"))
	player_role = str(payload.get("role", "-"))
	peer_id = int(payload.get("peer_id", NetworkService.get_unique_peer_id()))
	if NetworkService.is_network_server():
		_set_ui_state(STATE_HOSTING)
	else:
		_set_ui_state(STATE_CONNECTED)


func _on_client_disconnected() -> void:
	player_name = "-"
	player_role = "-"
	peer_id = 0
	_set_ui_state(STATE_OFFLINE)


func _on_network_error(_message: String) -> void:
	_set_ui_state(STATE_OFFLINE)
