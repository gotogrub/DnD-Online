extends Node
class_name GMToolStateSingleton
## Stores the local GM tool selection; server state still lives in SessionState.

signal tool_changed()

const TOOL_SPAWN_NPC := "spawn_npc"
const TOOL_SELECT_ACTOR := "select_actor"
const TOOL_MOVE_SELECTED := "move_selected"

var active_tool := ""
var selected_actor_id := ""
var selected_actor_ids := {}
var selected_npc_type := "goblin"
var selected_npc_name := ""


func set_tool(tool_name: String) -> void:
	var normalized_tool: String = tool_name.strip_edges()
	if not _is_valid_tool(normalized_tool):
		normalized_tool = ""
	if active_tool == normalized_tool:
		return
	active_tool = normalized_tool
	tool_changed.emit()


func set_gm_spawn_mode(npc_type: String, npc_name: String = "") -> void:
	var changed := active_tool != TOOL_SPAWN_NPC
	active_tool = TOOL_SPAWN_NPC
	selected_npc_type = npc_type.strip_edges().to_lower()
	if selected_npc_type.is_empty():
		selected_npc_type = "goblin"
	var normalized_name: String = npc_name.strip_edges().substr(0, MvpConstants.MAX_NAME_LENGTH)
	if selected_npc_name != normalized_name:
		changed = true
	selected_npc_name = normalized_name
	if changed:
		tool_changed.emit()


func clear_gm_tool() -> void:
	if active_tool.is_empty() and selected_npc_name.is_empty():
		return
	active_tool = ""
	selected_npc_name = ""
	tool_changed.emit()


func set_selected_actor(actor_id: String) -> void:
	var normalized_actor_id: String = actor_id.strip_edges()
	var next_selection := {}
	if not normalized_actor_id.is_empty():
		next_selection[normalized_actor_id] = true
	if selected_actor_id == normalized_actor_id and _selection_keys_match(next_selection):
		return
	selected_actor_ids = next_selection
	selected_actor_id = normalized_actor_id
	tool_changed.emit()


func toggle_selected_actor(actor_id: String) -> void:
	var normalized_actor_id: String = actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		return
	if selected_actor_ids.has(normalized_actor_id):
		selected_actor_ids.erase(normalized_actor_id)
	else:
		selected_actor_ids[normalized_actor_id] = true
	_update_primary_selected_actor()
	tool_changed.emit()


func remove_selected_actor(actor_id: String) -> void:
	var normalized_actor_id: String = actor_id.strip_edges()
	if normalized_actor_id.is_empty() or not selected_actor_ids.has(normalized_actor_id):
		return
	selected_actor_ids.erase(normalized_actor_id)
	_update_primary_selected_actor()
	tool_changed.emit()


func clear_selected_actor() -> void:
	if selected_actor_id.is_empty() and selected_actor_ids.is_empty():
		return
	selected_actor_id = ""
	selected_actor_ids.clear()
	tool_changed.emit()


func get_selected_actor_id() -> String:
	return selected_actor_id


func get_selected_actor_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_actor_id in selected_actor_ids.keys():
		result.append(str(raw_actor_id))
	return result


func get_selected_count() -> int:
	return selected_actor_ids.size()


func has_selected_actor(actor_id: String) -> bool:
	return selected_actor_ids.has(actor_id)


func can_move_selected_actor() -> bool:
	return selected_actor_ids.size() == 1 and not selected_actor_id.is_empty()


func is_select_actor_mode_active() -> bool:
	return active_tool == TOOL_SELECT_ACTOR


func is_move_selected_mode_active() -> bool:
	return active_tool == TOOL_MOVE_SELECTED


func is_gm_spawn_mode_active() -> bool:
	return active_tool == TOOL_SPAWN_NPC


func get_selected_npc_type() -> String:
	return selected_npc_type


func get_selected_npc_name() -> String:
	return selected_npc_name


func _is_valid_tool(tool_name: String) -> bool:
	return tool_name.is_empty() or tool_name == TOOL_SPAWN_NPC or tool_name == TOOL_SELECT_ACTOR or tool_name == TOOL_MOVE_SELECTED


func _update_primary_selected_actor() -> void:
	if selected_actor_ids.size() == 1:
		selected_actor_id = str(selected_actor_ids.keys()[0])
		return
	selected_actor_id = ""


func _selection_keys_match(next_selection: Dictionary) -> bool:
	if selected_actor_ids.size() != next_selection.size():
		return false
	for actor_id in selected_actor_ids.keys():
		if not next_selection.has(actor_id):
			return false
	return true
