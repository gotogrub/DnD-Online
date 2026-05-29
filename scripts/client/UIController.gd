extends Node
class_name UIController
## Connects UI widgets to network intents and displays server messages.

const STATE_MAIN_MENU := "main_menu"
const STATE_HOST_JOIN := "host_join"
const STATE_CHARACTER_SELECT := "character_select"
const STATE_CHARACTER_CREATE := "character_create"
const STATE_GAMEPLAY := "gameplay"
const STATE_IN_ENCOUNTER := "in_encounter"

var ui_root: Node
var pre_game_dim: CanvasItem
var main_menu_panel: Node
var connect_panel: Node
var chat_panel: Node
var dice_panel: Node
var character_panel: Node
var character_list_panel: Node
var create_character_panel: Node
var character_button: Button
var encounter_panel: Node
var gm_panel: Node
var debug_status: Label
var roll_toast_scene := preload("res://scenes/ui/RollToast.tscn")
var dice_roll_sound: AudioStream
var dice_roll_player: AudioStreamPlayer
var ui_state := STATE_MAIN_MENU
var last_non_encounter_state := STATE_MAIN_MENU
var player_name := "-"
var player_role := "-"
var peer_id := 0
var game_scene_path := ""


func bind_ui(root: Node) -> void:
	ui_root = root
	pre_game_dim = root.get_node_or_null("PreGameDim") as CanvasItem
	main_menu_panel = root.get_node_or_null("MainMenuPanel")
	connect_panel = root.get_node_or_null("ConnectPanel")
	chat_panel = root.get_node_or_null("ChatPanel")
	dice_panel = root.get_node_or_null("DicePanel")
	character_panel = root.get_node_or_null("CharacterSheetPanel")
	character_list_panel = root.get_node_or_null("CharacterListPanel")
	create_character_panel = root.get_node_or_null("CreateCharacterPanel")
	character_button = root.get_node_or_null("CharacterButton") as Button
	encounter_panel = root.get_node_or_null("EncounterPanel")
	gm_panel = root.get_node_or_null("GMPanel")
	debug_status = root.get_node_or_null("DebugStatus") as Label
	_connect_ui_signals()
	_setup_dice_roll_audio()
	_connect_network_signals()
	if SessionState.is_network_mode and SessionState.is_joined:
		_sync_local_identity_from_session()
		_set_ui_state(STATE_GAMEPLAY)
	else:
		_set_ui_state(STATE_MAIN_MENU)


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
	if not NetworkService.character_list_received.is_connected(_on_character_list_received):
		NetworkService.character_list_received.connect(_on_character_list_received)
	if not NetworkService.character_created.is_connected(_on_character_created):
		NetworkService.character_created.connect(_on_character_created)


func _connect_ui_signals() -> void:
	_connect_optional_signal(main_menu_panel, "host_requested", "_on_main_menu_host_requested")
	_connect_optional_signal(main_menu_panel, "join_requested", "_on_main_menu_join_requested")
	_connect_optional_signal(main_menu_panel, "quit_requested", "_on_main_menu_quit_requested")
	_connect_optional_signal(connect_panel, "back_requested", "_on_connect_back_requested")
	_connect_optional_signal(character_list_panel, "back_requested", "_on_character_select_back_requested")
	if character_button and not character_button.pressed.is_connected(_on_character_button_pressed):
		character_button.pressed.connect(_on_character_button_pressed)
	if character_list_panel and character_list_panel.has_signal("create_requested"):
		var create_callable := Callable(self, "_on_create_character_requested")
		if not character_list_panel.is_connected("create_requested", create_callable):
			character_list_panel.connect("create_requested", create_callable)
	if create_character_panel and create_character_panel.has_signal("back_requested"):
		var back_callable := Callable(self, "_on_create_character_back_requested")
		if not create_character_panel.is_connected("back_requested", back_callable):
			create_character_panel.connect("back_requested", back_callable)


func _connect_optional_signal(source: Object, signal_name: String, method_name: String) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	var signal_callable := Callable(self, method_name)
	if not source.is_connected(signal_name, signal_callable):
		source.connect(signal_name, signal_callable)


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
	var gameplay_like := new_state == STATE_GAMEPLAY or new_state == STATE_IN_ENCOUNTER
	var pre_game_like := new_state == STATE_MAIN_MENU or new_state == STATE_HOST_JOIN or new_state == STATE_CHARACTER_SELECT or new_state == STATE_CHARACTER_CREATE
	if pre_game_dim:
		pre_game_dim.visible = pre_game_like
	if main_menu_panel:
		main_menu_panel.visible = new_state == STATE_MAIN_MENU
	if connect_panel:
		connect_panel.visible = new_state == STATE_HOST_JOIN
	if chat_panel:
		chat_panel.visible = gameplay_like
	if dice_panel:
		dice_panel.visible = gameplay_like
	if character_button:
		character_button.visible = gameplay_like
	if character_panel:
		if not gameplay_like:
			character_panel.visible = false
	if character_list_panel:
		character_list_panel.visible = new_state == STATE_CHARACTER_SELECT
	if create_character_panel:
		create_character_panel.visible = new_state == STATE_CHARACTER_CREATE
	if encounter_panel:
		var encounter_visible := new_state == STATE_IN_ENCOUNTER
		if encounter_panel.has_method("set_encounter_visible"):
			encounter_panel.set_encounter_visible(encounter_visible)
		else:
			encounter_panel.visible = encounter_visible
	if gm_panel:
		var gm_visible: bool = gameplay_like and player_role == MvpConstants.ROLE_GM
		if gm_panel.has_method("set_gm_visible"):
			gm_panel.set_gm_visible(gm_visible)
		else:
			gm_panel.visible = gm_visible
	if debug_status:
		debug_status.visible = gameplay_like
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
	player_name = NetworkService.player_name.strip_edges()
	if player_name.is_empty():
		player_name = "Host"
	player_role = "-"
	_set_ui_state(STATE_CHARACTER_SELECT)


func _on_join_accepted(payload: Dictionary) -> void:
	player_name = str(payload.get("name", "-"))
	player_role = str(payload.get("role", "-"))
	peer_id = int(payload.get("peer_id", NetworkService.get_unique_peer_id()))
	if character_list_panel:
		character_list_panel.visible = false
	if create_character_panel:
		create_character_panel.visible = false
	_set_ui_state(STATE_GAMEPLAY)
	if not game_scene_path.is_empty():
		call_deferred("_change_to_game_scene")


func _on_client_disconnected() -> void:
	player_name = "-"
	player_role = "-"
	peer_id = 0
	_set_ui_state(STATE_MAIN_MENU)


func _on_network_error(_message: String) -> void:
	_set_ui_state(STATE_MAIN_MENU)


func _on_roll_result_received(_payload: Dictionary) -> void:
	_play_dice_roll_sound()


func _on_character_list_received(payload: Dictionary) -> void:
	if not SessionState.is_joined:
		_set_ui_state(STATE_CHARACTER_SELECT)
		if character_list_panel and character_list_panel.has_method("show_character_list"):
			character_list_panel.show_character_list(payload)


func _on_character_created(payload: Dictionary) -> void:
	player_name = str(payload.get("name", player_name))
	player_role = str(payload.get("role", player_role))
	if create_character_panel:
		create_character_panel.visible = false
	if character_list_panel:
		character_list_panel.visible = false
	_update_debug_status()


func _on_create_character_requested() -> void:
	if character_list_panel:
		character_list_panel.visible = false
	_set_ui_state(STATE_CHARACTER_CREATE)
	if create_character_panel and create_character_panel.has_method("open_panel"):
		create_character_panel.open_panel()


func _on_create_character_back_requested() -> void:
	_set_ui_state(STATE_CHARACTER_SELECT)
	if character_list_panel and character_list_panel.has_method("show_character_list"):
		character_list_panel.show_character_list({
			"owner_key": SessionState.local_owner_key,
			"characters": SessionState.get_available_characters(),
			"last_character_id": SessionState.last_character_id,
		})


func _on_main_menu_host_requested() -> void:
	if connect_panel and connect_panel.has_method("set_mode"):
		connect_panel.set_mode("host")
	_set_ui_state(STATE_HOST_JOIN)


func _on_main_menu_join_requested() -> void:
	if connect_panel and connect_panel.has_method("set_mode"):
		connect_panel.set_mode("join")
	_set_ui_state(STATE_HOST_JOIN)


func _on_main_menu_quit_requested() -> void:
	get_tree().quit()


func _on_connect_back_requested() -> void:
	NetworkService.disconnect_from_network()
	_reset_local_ui_identity()
	_set_ui_state(STATE_MAIN_MENU)


func _on_character_select_back_requested() -> void:
	NetworkService.disconnect_from_network()
	_reset_local_ui_identity()
	_set_ui_state(STATE_MAIN_MENU)


func _reset_local_ui_identity() -> void:
	player_name = "-"
	player_role = "-"
	peer_id = 0


func _sync_local_identity_from_session() -> void:
	peer_id = NetworkService.get_unique_peer_id()
	player_role = SessionState.local_role
	var local_player: Dictionary = SessionState.get_player(SessionState.local_peer_id)
	player_name = str(local_player.get(EntityData.NAME, SessionState.get_local_character().get("name", "-")))
	if player_role.is_empty():
		player_role = "-"
	if player_name.is_empty():
		player_name = "-"


func _change_to_game_scene() -> void:
	if game_scene_path.is_empty():
		return
	var error: int = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		push_warning("Could not change to game scene: %s" % game_scene_path)


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
	if ui_state != STATE_GAMEPLAY and ui_state != STATE_IN_ENCOUNTER:
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
