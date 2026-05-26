extends PanelContainer
class_name GMPanel
## Lets the local GM choose an NPC template and enter click-to-spawn mode.

const NPC_TYPE_KEYS := ["goblin", "raider", "guard", "merchant"]
const NPC_TYPE_LABELS := ["Goblin", "Raider", "Guard", "Merchant"]

@onready var npc_type_option: OptionButton = $VBoxContainer/NpcTypeOption
@onready var custom_name_input: LineEdit = $VBoxContainer/CustomNameInput
@onready var spawn_mode_check_box: CheckBox = $VBoxContainer/SpawnModeCheckBox
@onready var status_label: Label = $VBoxContainer/StatusLabel


func _ready() -> void:
	custom_name_input.max_length = MvpConstants.MAX_NAME_LENGTH
	_populate_npc_types()
	npc_type_option.item_selected.connect(_on_npc_type_selected)
	custom_name_input.text_changed.connect(_on_custom_name_changed)
	spawn_mode_check_box.toggled.connect(_on_spawn_mode_toggled)
	GMToolState.tool_changed.connect(_on_tool_changed)
	NetworkService.system_message_received.connect(_on_system_message_received)
	set_gm_visible(false)


func set_gm_visible(visible_for_gm: bool) -> void:
	visible = visible_for_gm
	if not visible_for_gm:
		spawn_mode_check_box.set_pressed_no_signal(false)
		GMToolState.clear_gm_tool()
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
	GMToolState.clear_gm_tool()


func _on_npc_type_selected(_index: int) -> void:
	_refresh_active_tool()


func _on_custom_name_changed(_new_text: String) -> void:
	_refresh_active_tool()


func _on_tool_changed() -> void:
	_update_status_from_tool()


func _update_status_from_tool() -> void:
	if spawn_mode_check_box.button_pressed != GMToolState.is_gm_spawn_mode_active():
		spawn_mode_check_box.set_pressed_no_signal(GMToolState.is_gm_spawn_mode_active())
	if GMToolState.is_gm_spawn_mode_active():
		set_status("Spawn mode active: click tiles")
	else:
		set_status("Select NPC type and click tile")


func _refresh_active_tool() -> void:
	if not GMToolState.is_gm_spawn_mode_active():
		return
	GMToolState.set_gm_spawn_mode(_selected_npc_type(), custom_name_input.text)


func _on_system_message_received(payload: Dictionary) -> void:
	var message: String = str(payload.get("message", ""))
	if message.begins_with("Spawn"):
		set_status(message)
