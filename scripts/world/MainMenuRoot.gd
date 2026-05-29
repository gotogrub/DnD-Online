extends Node
class_name MainMenuRoot
## Runs the pre-game menu/character flow before loading the board scene.

const GAME_SCENE_PATH := "res://scenes/main/MvpRoot.tscn"

@onready var ui_root: CanvasLayer = $UI
@onready var ui_controller := UIController.new()


func _ready() -> void:
	add_child(ui_controller)
	ui_controller.game_scene_path = GAME_SCENE_PATH
	ui_controller.bind_ui(ui_root)
