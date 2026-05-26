extends Node
class_name MvpRoot
## Wires the root MVP scene without starting multiplayer automatically.

@onready var board: Node = $ProtoBoard
@onready var ui_root: CanvasLayer = $UI
@onready var input_controller := InputController.new()
@onready var ui_controller := UIController.new()
@onready var client_main := ClientMain.new()

var world_renderer: WorldRenderer


func _ready() -> void:
	if board.has_method("get_world_renderer"):
		world_renderer = board.get_world_renderer() as WorldRenderer
	if not world_renderer:
		world_renderer = WorldRenderer.new()
		add_child(world_renderer)
		world_renderer.bind_board(board)
		world_renderer.render_full_state(SessionState.get_actors())
	add_child(input_controller)
	add_child(ui_controller)
	add_child(client_main)
	input_controller.bind_board(board)
	ui_controller.bind_ui(ui_root)
	if board.has_signal("tile_clicked"):
		board.tile_clicked.connect(input_controller.handle_tile_clicked)
	client_main.boot({
		"world_renderer": world_renderer,
		"ui_controller": ui_controller,
		"input_controller": input_controller,
	})
