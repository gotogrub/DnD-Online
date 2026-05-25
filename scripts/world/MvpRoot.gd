extends Node
class_name MvpRoot
## Wires the root MVP scene without starting multiplayer automatically.

@onready var board: Node = $ProtoBoard
@onready var ui_root: CanvasLayer = $UI
@onready var world_renderer := WorldRenderer.new()
@onready var input_controller := InputController.new()
@onready var ui_controller := UIController.new()
@onready var client_main := ClientMain.new()


func _ready() -> void:
	add_child(world_renderer)
	add_child(input_controller)
	add_child(ui_controller)
	add_child(client_main)
	world_renderer.bind_board(board)
	input_controller.bind_board(board)
	ui_controller.bind_ui(ui_root)
	if board.has_signal("tile_clicked"):
		board.tile_clicked.connect(input_controller.handle_tile_clicked)
	client_main.boot({
		"world_renderer": world_renderer,
		"ui_controller": ui_controller,
		"input_controller": input_controller,
	})
