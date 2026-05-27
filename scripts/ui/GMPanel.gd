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
@onready var selected_label: Label = $VBoxContainer/SelectedLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _ready() -> void:
	custom_name_input.max_length = MvpConstants.MAX_NAME_LENGTH
	_populate_npc_types()
	npc_type_option.item_selected.connect(_on_npc_type_selected)
	custom_name_input.text_changed.connect(_on_custom_name_changed)
	spawn_mode_check_box.toggled.connect(_on_spawn_mode_toggled)
	select_actor_check_box.toggled.connect(_on_select_actor_toggled)
	move_selected_check_box.toggled.connect(_on_move_selected_toggled)
	delete_selected_button.pressed.connect(_on_delete_selected_pressed)
	GMToolState.tool_changed.connect(_on_tool_changed)
	SessionState.actors_changed.connect(_on_actors_changed)
	NetworkService.system_message_received.connect(_on_system_message_received)
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
	_update_status_from_tool()


func set_status(text: String) -> void:
	status_label.text = text


func _populate_npc_types() -> void:
	npc_type_option.clear()
	for index in range(NPC_TYPE_LABELS.size()):
		npc_type_option.add_item(str(NPC_TYPE_LABELS[index]))
		npc_type_option.set_item_metadata(index, str(NPC_TYPE_KEYS[index]))
	npc_type_option.select(0)


func _selected_npc_type() -> String:
	var selected_index: int = npc_type_option.selected
	if selected_index < 0 or selected_index >= NPC_TYPE_KEYS.size():
		return "goblin"
	return str(NPC_TYPE_KEYS[selected_index])


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
