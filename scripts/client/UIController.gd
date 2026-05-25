extends Node
class_name UIController
## Connects UI widgets to network intents and displays server messages.

var ui_root: Node
var chat_panel: Node
var encounter_panel: Node
var roll_toast_scene := preload("res://scenes/ui/RollToast.tscn")


func bind_ui(root: Node) -> void:
	ui_root = root
	chat_panel = root.get_node_or_null("ChatPanel")
	encounter_panel = root.get_node_or_null("EncounterPanel")


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
