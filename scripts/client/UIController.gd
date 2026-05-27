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
var character_panel: Node
var character_button: Button
var encounter_panel: Node
var gm_panel: Node
var debug_status: Label
var roll_toast_scene := preload("res://scenes/ui/RollToast.tscn")
var dice_roll_sound: AudioStream
var dice_roll_player: AudioStreamPlayer
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
	character_panel = root.get_node_or_null("CharacterSheetPanel")
	character_button = root.get_node_or_null("CharacterButton") as Button
	encounter_panel = root.get_node_or_null("EncounterPanel")
	gm_panel = root.get_node_or_null("GMPanel")
	debug_status = root.get_node_or_null("DebugStatus") as Label
	_connect_ui_signals()
	_setup_dice_roll_audio()
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
	if not NetworkService.roll_result_received.is_connected(_on_roll_result_received):
		NetworkService.roll_result_received.connect(_on_roll_result_received)


func _connect_ui_signals() -> void:
	if character_button and not character_button.pressed.is_connected(_on_character_button_pressed):
		character_button.pressed.connect(_on_character_button_pressed)


func _setup_dice_roll_audio() -> void:
	if not ui_root or dice_roll_player:
		return
	if ResourceLoader.exists(MvpConstants.DICE_ROLL_SOUND):
		dice_roll_sound = load(MvpConstants.DICE_ROLL_SOUND) as AudioStream
	if not dice_roll_sound:
		return
	dice_roll_player = AudioStreamPlayer.new()
	dice_roll_player.name = "DiceRollAudio"
	dice_roll_player.stream = dice_roll_sound
	dice_roll_player.volume_db = MvpConstants.DICE_ROLL_VOLUME_DB
	ui_root.add_child(dice_roll_player)


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
	if character_button:
		character_button.visible = connected_like
	if character_panel:
		if not connected_like:
			character_panel.visible = false
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


func _on_roll_result_received(_payload: Dictionary) -> void:
	_play_dice_roll_sound()


func _on_character_button_pressed() -> void:
	_toggle_character_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_C:
		return
	if _is_text_input_focused():
		return
	_toggle_character_panel()
	get_viewport().set_input_as_handled()


func _toggle_character_panel() -> void:
	if not character_panel:
		return
	if character_button and not character_button.visible:
		return
	character_panel.visible = not character_panel.visible
	if character_panel.visible and character_panel.has_method("refresh"):
		character_panel.refresh()


func _is_text_input_focused() -> bool:
	var focused_control: Control = get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit


func _play_dice_roll_sound() -> void:
	if not dice_roll_player:
		return
	if dice_roll_player.playing:
		dice_roll_player.stop()
	dice_roll_player.play()
