extends Node
class_name ClientMain
## Coordinates client-side controllers and renderers for the MVP shell.

var world_renderer: WorldRenderer
var ui_controller: UIController
var input_controller: InputController


func boot(options: Dictionary = {}) -> void:
	world_renderer = options.get("world_renderer", world_renderer) as WorldRenderer
	ui_controller = options.get("ui_controller", ui_controller) as UIController
	input_controller = options.get("input_controller", input_controller) as InputController
	if not SessionState.state_changed.is_connected(_on_state_changed):
		SessionState.state_changed.connect(_on_state_changed)


func shutdown() -> void:
	if SessionState.state_changed.is_connected(_on_state_changed):
		SessionState.state_changed.disconnect(_on_state_changed)


func apply_snapshot(snapshot: Dictionary) -> void:
	SessionState.apply_snapshot(snapshot)
	if world_renderer:
		world_renderer.render_snapshot(snapshot)


func _on_state_changed() -> void:
	# Actor visuals are updated by WorldRenderer through SessionState actor signals.
	pass
