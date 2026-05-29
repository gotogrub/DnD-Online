extends PanelContainer
class_name MainMenuPanel
## Lightweight entry overlay for choosing Host or Join without changing scenes.

signal host_requested()
signal join_requested()
signal quit_requested()

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_host_pressed() -> void:
	host_requested.emit()


func _on_join_pressed() -> void:
	join_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
