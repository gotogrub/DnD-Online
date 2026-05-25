extends PanelContainer
class_name ConnectPanel
## Collects local connection settings and calls NetworkService lifecycle methods.

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var address_input: LineEdit = $VBoxContainer/AddressInput
@onready var port_input: SpinBox = $VBoxContainer/PortInput
@onready var host_button: Button = $VBoxContainer/Buttons/HostButton
@onready var join_button: Button = $VBoxContainer/Buttons/JoinButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)


func _on_host_pressed() -> void:
	NetworkService.start_server(int(port_input.value))


func _on_join_pressed() -> void:
	NetworkService.connect_to_server(address_input.text, int(port_input.value), name_input.text)
