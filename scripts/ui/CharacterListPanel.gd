extends PanelContainer
class_name CharacterListPanel
## Shows server-side characters for the current owner and selects one before actor spawn.

signal create_requested()
signal back_requested()

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var rows_container: VBoxContainer = $VBoxContainer/ScrollContainer/Rows
@onready var select_button: Button = $VBoxContainer/ButtonRow/SelectButton
@onready var create_button: Button = $VBoxContainer/ButtonRow/CreateButton
@onready var delete_button: Button = $VBoxContainer/ButtonRow/DeleteButton
@onready var close_button: Button = $VBoxContainer/ButtonRow/CloseButton

var character_summaries: Array[Dictionary] = []
var selected_character_id := ""
var last_character_id := ""


func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	create_button.pressed.connect(_on_create_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(_on_close_pressed)
	if not SessionState.character_list_changed.is_connected(_on_character_list_changed):
		SessionState.character_list_changed.connect(_on_character_list_changed)
	if not NetworkService.character_select_rejected.is_connected(_on_character_select_rejected):
		NetworkService.character_select_rejected.connect(_on_character_select_rejected)
	if not NetworkService.character_deleted.is_connected(_on_character_deleted):
		NetworkService.character_deleted.connect(_on_character_deleted)
	if not NetworkService.character_delete_rejected.is_connected(_on_character_delete_rejected):
		NetworkService.character_delete_rejected.connect(_on_character_delete_rejected)
	if not NetworkService.join_accepted.is_connected(_on_join_accepted):
		NetworkService.join_accepted.connect(_on_join_accepted)
	_apply_character_list({
		"characters": SessionState.get_available_characters(),
		"last_character_id": SessionState.last_character_id,
	}, false)


func show_character_list(payload: Dictionary) -> void:
	_apply_character_list(payload, true)


func _on_character_list_changed(payload: Dictionary) -> void:
	_apply_character_list(payload, false)


func _apply_character_list(payload: Dictionary, force_visible: bool) -> void:
	character_summaries.clear()
	var raw_characters: Variant = payload.get("characters", [])
	if raw_characters is Array:
		for raw_summary: Variant in raw_characters:
			if raw_summary is Dictionary:
				character_summaries.append((raw_summary as Dictionary).duplicate(true))
	last_character_id = str(payload.get("last_character_id", ""))
	_pick_initial_selection()
	_rebuild_rows()
	_update_status()
	if force_visible:
		visible = true


func _pick_initial_selection() -> void:
	var local_character_id: String = _local_character_id()
	if _has_character(local_character_id):
		selected_character_id = local_character_id
		return
	if _has_character(last_character_id):
		selected_character_id = last_character_id
		return
	if not character_summaries.is_empty():
		selected_character_id = str(character_summaries[0].get("character_id", ""))
	else:
		selected_character_id = ""


func _rebuild_rows() -> void:
	for child: Node in rows_container.get_children():
		child.queue_free()
	for summary: Dictionary in character_summaries:
		var character_id: String = str(summary.get("character_id", ""))
		var row_button := Button.new()
		row_button.toggle_mode = true
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.text = _format_summary(summary)
		row_button.tooltip_text = character_id
		row_button.set_meta("character_id", character_id)
		row_button.pressed.connect(_on_row_pressed.bind(character_id))
		rows_container.add_child(row_button)
	_refresh_row_selection()


func _refresh_row_selection() -> void:
	for child: Node in rows_container.get_children():
		var row_button := child as Button
		if row_button == null:
			continue
		var character_id: String = str(row_button.get_meta("character_id", ""))
		row_button.set_pressed_no_signal(character_id == selected_character_id)
	select_button.disabled = selected_character_id.is_empty()
	delete_button.disabled = selected_character_id.is_empty() or _selected_character_is_active()


func _format_summary(summary: Dictionary) -> String:
	var character_id: String = str(summary.get("character_id", ""))
	var marker: String = " *" if character_id == _local_character_id() else ""
	return "%s%s\n%s | level %d | %s\nID: %s" % [
		str(summary.get("name", "Character")),
		marker,
		str(summary.get("race_name", summary.get("race_id", "human"))),
		int(summary.get("level", 1)),
		_format_last_used(int(summary.get("last_used_at", 0))),
		character_id,
	]


func _format_last_used(last_used_at: int) -> String:
	if last_used_at <= 0:
		return "new"
	return "last used: %d" % last_used_at


func _update_status() -> void:
	if character_summaries.is_empty():
		status_label.text = "No characters yet. Create one to join."
		return
	if selected_character_id == _local_character_id():
		status_label.text = "Current character selected."
	else:
		status_label.text = "Select a character to enter the game."


func _on_row_pressed(character_id: String) -> void:
	selected_character_id = character_id
	_refresh_row_selection()
	_update_status()


func _on_select_pressed() -> void:
	if selected_character_id.is_empty():
		_set_status_and_system_message("Select a character first.")
		return
	select_button.disabled = true
	status_label.text = "Selecting character..."
	if not NetworkService.request_select_character(selected_character_id):
		select_button.disabled = false
		status_label.text = "Could not send select request."


func _on_create_pressed() -> void:
	create_requested.emit()


func _on_delete_pressed() -> void:
	if selected_character_id.is_empty():
		_set_status_and_system_message("Select a character first.")
		return
	if _selected_character_is_active():
		_set_status_and_system_message("Cannot delete the active character.")
		return
	delete_button.disabled = true
	select_button.disabled = true
	status_label.text = "Deleting character..."
	if not NetworkService.request_delete_character(selected_character_id):
		_refresh_row_selection()
		status_label.text = "Could not send delete request."


func _on_close_pressed() -> void:
	if SessionState.is_character_selecting and not SessionState.is_joined:
		back_requested.emit()
		return
	visible = false


func _on_character_select_rejected(payload: Dictionary) -> void:
	select_button.disabled = selected_character_id.is_empty()
	status_label.text = str(payload.get("reason", "select character rejected"))


func _on_character_deleted(payload: Dictionary) -> void:
	var deleted_character_id: String = str(payload.get("character_id", ""))
	if selected_character_id == deleted_character_id:
		selected_character_id = ""
	status_label.text = "Character deleted."
	_refresh_row_selection()


func _on_character_delete_rejected(payload: Dictionary) -> void:
	_refresh_row_selection()
	status_label.text = str(payload.get("reason", "delete character rejected"))


func _on_join_accepted(_payload: Dictionary) -> void:
	select_button.disabled = false
	delete_button.disabled = false
	visible = false


func _set_status_and_system_message(message: String) -> void:
	status_label.text = message
	print(message)
	NetworkService.system_message_received.emit({
		"kind": "system",
		"message": message,
		"server_time": Time.get_unix_time_from_system(),
	})


func _local_character_id() -> String:
	return str(SessionState.get_local_character().get("character_id", ""))


func _has_character(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	for summary: Dictionary in character_summaries:
		if str(summary.get("character_id", "")) == character_id:
			return true
	return false


func _selected_character_is_active() -> bool:
	return SessionState.is_joined and selected_character_id == _local_character_id()
