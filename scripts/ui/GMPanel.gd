extends PanelContainer
class_name GMPanel
## Lets the local GM choose an NPC template and enter click-to-spawn mode.

const NPC_TYPE_KEYS := ["goblin", "raider", "guard", "merchant"]
const NPC_TYPE_LABELS := ["Goblin", "Raider", "Guard", "Merchant"]

@onready var npc_type_option: OptionButton = $VBoxContainer/NpcTypeOption
@onready var custom_name_input: LineEdit = $VBoxContainer/CustomNameInput
@onready var spawn_mode_check_box: CheckBox = $VBoxContainer/SpawnModeCheckBox
@onready var select_actor_check_box: CheckBox = $VBoxContainer/SelectActorCheckBox
@onready var move_selected_check_box: CheckBox = $VBoxContainer/MoveSelectedCheckBox
@onready var delete_selected_button: Button = $VBoxContainer/DeleteSelectedButton
@onready var player_option: OptionButton = $VBoxContainer/PlayerOption
@onready var item_option: OptionButton = $VBoxContainer/ItemOption
@onready var item_quantity: SpinBox = $VBoxContainer/ItemQuantity
@onready var give_item_button: Button = $VBoxContainer/GiveItemButton
@onready var item_status_label: Label = $VBoxContainer/ItemStatusLabel
@onready var selected_label: Label = $VBoxContainer/SelectedLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _ready() -> void:
	custom_name_input.max_length = MvpConstants.MAX_NAME_LENGTH
	_populate_npc_types()
	_populate_item_types()
	_populate_player_targets_from_state()
	item_quantity.max_value = MvpConstants.MAX_ITEM_GIVE_QUANTITY
	npc_type_option.item_selected.connect(_on_npc_type_selected)
	custom_name_input.text_changed.connect(_on_custom_name_changed)
	spawn_mode_check_box.toggled.connect(_on_spawn_mode_toggled)
	select_actor_check_box.toggled.connect(_on_select_actor_toggled)
	move_selected_check_box.toggled.connect(_on_move_selected_toggled)
	delete_selected_button.pressed.connect(_on_delete_selected_pressed)
	player_option.pressed.connect(_on_player_option_pressed)
	give_item_button.pressed.connect(_on_give_item_pressed)
	GMToolState.tool_changed.connect(_on_tool_changed)
	SessionState.actors_changed.connect(_on_actors_changed)
	NetworkService.system_message_received.connect(_on_system_message_received)
	NetworkService.player_list_received.connect(_on_player_list_received)
	set_gm_visible(false)


func set_gm_visible(visible_for_gm: bool) -> void:
	visible = visible_for_gm
	if not visible_for_gm:
		spawn_mode_check_box.set_pressed_no_signal(false)
		select_actor_check_box.set_pressed_no_signal(false)
		move_selected_check_box.set_pressed_no_signal(false)
		GMToolState.clear_gm_tool()
		GMToolState.clear_selected_actor()
		return
	_populate_player_targets_from_state()
	NetworkService.request_player_list()
	_update_status_from_tool()


func set_status(text: String) -> void:
	status_label.text = text


func _populate_npc_types() -> void:
	npc_type_option.clear()
	for index in range(NPC_TYPE_LABELS.size()):
		npc_type_option.add_item(str(NPC_TYPE_LABELS[index]))
		npc_type_option.set_item_metadata(index, str(NPC_TYPE_KEYS[index]))
	npc_type_option.select(0)


func _populate_item_types() -> void:
	item_option.clear()
	var items: Array = ItemRegistry.get_all_items()
	for raw_item in items:
		var item: Dictionary = raw_item as Dictionary
		var item_id: String = str(item.get("item_id", ""))
		if item_id.is_empty():
			continue
		item_option.add_item(str(item.get("name", item_id)))
		item_option.set_item_metadata(item_option.get_item_count() - 1, item_id)
	if item_option.get_item_count() > 0:
		item_option.select(0)


func _selected_npc_type() -> String:
	var selected_index: int = npc_type_option.selected
	if selected_index < 0 or selected_index >= NPC_TYPE_KEYS.size():
		return "goblin"
	return str(NPC_TYPE_KEYS[selected_index])


func _selected_item_id() -> String:
	var selected_index: int = item_option.selected
	if selected_index < 0 or selected_index >= item_option.get_item_count():
		return ""
	return str(item_option.get_item_metadata(selected_index))


func _selected_target_character_id() -> String:
	var selected_index: int = player_option.selected
	if selected_index < 0 or selected_index >= player_option.get_item_count():
		return ""
	return str(player_option.get_item_metadata(selected_index))


func _populate_player_targets_from_state() -> void:
	var rows: Array = []
	var players: Dictionary = SessionState.get_players()
	for raw_peer_id in players.keys():
		var peer_id: int = int(raw_peer_id)
		var player: Dictionary = players.get(raw_peer_id, {}) as Dictionary
		var character_id: String = str(player.get(EntityData.CHARACTER_ID, ""))
		if character_id.is_empty():
			continue
		rows.append({
			"peer_id": peer_id,
			"character_id": character_id,
			"name": str(player.get(EntityData.NAME, "Player")),
			"role": str(player.get(EntityData.ROLE, MvpConstants.ROLE_PLAYER)),
		})
	_populate_player_targets(rows)


func _populate_player_targets(players: Array) -> void:
	var previous_character_id: String = _selected_target_character_id()
	if previous_character_id.is_empty():
		previous_character_id = SessionState.local_character_id
	player_option.clear()
	var selected_index := 0
	for raw_player in players:
		var player: Dictionary = raw_player as Dictionary
		var character_id: String = str(player.get("character_id", ""))
		if character_id.is_empty():
			continue
		var player_name: String = str(player.get("name", "Player"))
		var role: String = str(player.get("role", MvpConstants.ROLE_PLAYER))
		var peer_id: int = int(player.get("peer_id", 0))
		var label: String = "%s (%s)" % [player_name, role]
		if peer_id == SessionState.local_peer_id:
			label = "%s - self" % label
		player_option.add_item(label)
		var item_index: int = player_option.get_item_count() - 1
		player_option.set_item_metadata(item_index, character_id)
		if character_id == previous_character_id:
			selected_index = item_index
	if player_option.get_item_count() == 0:
		player_option.add_item("No joined players")
		player_option.set_item_metadata(0, "")
		player_option.disabled = true
		give_item_button.disabled = true
		return
	player_option.disabled = false
	give_item_button.disabled = false
	player_option.select(selected_index)


func _on_spawn_mode_toggled(enabled: bool) -> void:
	if enabled:
		GMToolState.set_gm_spawn_mode(_selected_npc_type(), custom_name_input.text)
		return
	if GMToolState.is_gm_spawn_mode_active():
		GMToolState.clear_gm_tool()


func _on_select_actor_toggled(enabled: bool) -> void:
	if enabled:
		GMToolState.set_tool(GMToolState.TOOL_SELECT_ACTOR)
		return
	if GMToolState.is_select_actor_mode_active():
		GMToolState.clear_gm_tool()


func _on_move_selected_toggled(enabled: bool) -> void:
	if enabled:
		GMToolState.set_tool(GMToolState.TOOL_MOVE_SELECTED)
		return
	if GMToolState.is_move_selected_mode_active():
		GMToolState.clear_gm_tool()


func _on_delete_selected_pressed() -> void:
	var actor_ids: Array[String] = GMToolState.get_selected_actor_ids()
	if actor_ids.is_empty():
		set_status("Select actor first")
		return
	NetworkService.request_gm_delete_actors(actor_ids)


func _on_player_option_pressed() -> void:
	item_status_label.text = "Refreshing players..."
	NetworkService.request_player_list()


func _on_player_list_received(payload: Dictionary) -> void:
	var raw_players: Variant = payload.get("players", [])
	if raw_players is Array:
		_populate_player_targets(raw_players as Array)
	else:
		_populate_player_targets([])
	if player_option.disabled:
		item_status_label.text = "No joined players"
	elif item_status_label.text == "Refreshing players...":
		item_status_label.text = "Select player, item and quantity"


func _on_give_item_pressed() -> void:
	var target_character_id: String = _selected_target_character_id()
	if target_character_id.is_empty():
		item_status_label.text = "Select player first"
		return
	var item_id: String = _selected_item_id()
	var quantity: int = int(item_quantity.value)
	if item_id.is_empty():
		item_status_label.text = "Select item first"
		return
	if not NetworkService.request_gm_give_item_to_character(target_character_id, item_id, quantity):
		item_status_label.text = "Could not send item request"
		return
	item_status_label.text = "Item request sent"


func _on_npc_type_selected(_index: int) -> void:
	_refresh_active_tool()


func _on_custom_name_changed(_new_text: String) -> void:
	_refresh_active_tool()


func _on_tool_changed() -> void:
	_update_status_from_tool()


func _update_status_from_tool() -> void:
	if spawn_mode_check_box.button_pressed != GMToolState.is_gm_spawn_mode_active():
		spawn_mode_check_box.set_pressed_no_signal(GMToolState.is_gm_spawn_mode_active())
	if select_actor_check_box.button_pressed != GMToolState.is_select_actor_mode_active():
		select_actor_check_box.set_pressed_no_signal(GMToolState.is_select_actor_mode_active())
	if move_selected_check_box.button_pressed != GMToolState.is_move_selected_mode_active():
		move_selected_check_box.set_pressed_no_signal(GMToolState.is_move_selected_mode_active())
	_update_selected_label()
	if GMToolState.is_gm_spawn_mode_active():
		set_status("Spawn mode active: click tiles")
	elif GMToolState.is_select_actor_mode_active():
		set_status("Select actor mode: click actor tile")
	elif GMToolState.is_move_selected_mode_active():
		var selected_count: int = GMToolState.get_selected_count()
		if selected_count == 0:
			set_status("Select actor first")
		elif selected_count > 1:
			set_status("Move Selected requires one actor")
		else:
			set_status("Move selected: click destination")
	else:
		set_status("Select NPC type and click tile")


func _refresh_active_tool() -> void:
	if not GMToolState.is_gm_spawn_mode_active():
		return
	GMToolState.set_gm_spawn_mode(_selected_npc_type(), custom_name_input.text)


func _update_selected_label() -> void:
	var actor_ids: Array[String] = GMToolState.get_selected_actor_ids()
	if actor_ids.is_empty():
		selected_label.text = "Selected: none"
		delete_selected_button.disabled = true
		return
	if actor_ids.size() > 1:
		selected_label.text = "Selected: %d actors" % actor_ids.size()
		delete_selected_button.disabled = false
		return
	var actor_id: String = actor_ids[0]
	var actor: Dictionary = SessionState.get_actor(actor_id)
	if actor.is_empty():
		selected_label.text = "Selected: missing (%s)" % actor_id
		delete_selected_button.disabled = true
		return
	selected_label.text = "Selected: %s (%s)" % [
		str(actor.get(EntityData.NAME, actor_id)),
		actor_id,
	]
	delete_selected_button.disabled = false


func _on_actors_changed() -> void:
	if not visible:
		return
	for actor_id in GMToolState.get_selected_actor_ids():
		if not SessionState.has_actor(actor_id):
			GMToolState.remove_selected_actor(actor_id)
	_update_selected_label()


func _on_system_message_received(payload: Dictionary) -> void:
	var message: String = str(payload.get("message", ""))
	if message.begins_with("Deleted"):
		GMToolState.clear_selected_actor()
	if message.begins_with("Spawn") or message.begins_with("Delete"):
		set_status(message)
	if message.begins_with("Gave") or message.begins_with("Give item"):
		item_status_label.text = message
