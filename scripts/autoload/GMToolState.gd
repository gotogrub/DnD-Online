extends Node
class_name GMToolStateSingleton
## Stores the local GM tool selection; server state still lives in SessionState.

signal tool_changed()

const TOOL_SPAWN_NPC := "spawn_npc"

var active_tool := ""
var selected_npc_type := "goblin"
var selected_npc_name := ""


func set_gm_spawn_mode(npc_type: String, npc_name: String = "") -> void:
	active_tool = TOOL_SPAWN_NPC
	selected_npc_type = npc_type.strip_edges().to_lower()
	if selected_npc_type.is_empty():
		selected_npc_type = "goblin"
	selected_npc_name = npc_name.strip_edges().substr(0, MvpConstants.MAX_NAME_LENGTH)
	tool_changed.emit()


func clear_gm_tool() -> void:
	if active_tool.is_empty() and selected_npc_name.is_empty():
		return
	active_tool = ""
	selected_npc_name = ""
	tool_changed.emit()


func is_gm_spawn_mode_active() -> bool:
	return active_tool == TOOL_SPAWN_NPC


func get_selected_npc_type() -> String:
	return selected_npc_type


func get_selected_npc_name() -> String:
	return selected_npc_name
