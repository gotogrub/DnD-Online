extends PanelContainer
class_name ConnectPanel
## Collects local connection settings and calls NetworkService lifecycle methods.

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var address_input: LineEdit = $VBoxContainer/AddressInput
@onready var port_input: SpinBox = $VBoxContainer/PortInput
@onready var host_button: Button = $VBoxContainer/Buttons/HostButton
@onready var join_button: Button = $VBoxContainer/Buttons/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var collapse_button: Button = $VBoxContainer/CollapseButton

var is_collapsed := false


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	collapse_button.pressed.connect(_on_collapse_pressed)
	NetworkService.server_started.connect(_on_server_started)
	NetworkService.client_connected.connect(_set_connected)
	NetworkService.client_disconnected.connect(_set_disconnected)
	NetworkService.join_accepted.connect(_on_join_accepted)
	NetworkService.network_error.connect(_set_status)
	set_collapsed(false)


func _on_host_pressed() -> void:
	NetworkService.start_server(int(port_input.value))


func _on_join_pressed() -> void:
	if NetworkService.connect_to_server(address_input.text, int(port_input.value), name_input.text):
		_set_status("connecting")


func _on_server_started(_port: int) -> void:
	_set_status("server started")


func _set_connected() -> void:
	_set_status("connected")


func _set_disconnected() -> void:
	_set_status("disconnected")


func _on_join_accepted(_payload: Dictionary) -> void:
	_set_status("join accepted")


func _set_status(text: String) -> void:
	status_label.text = text
	print(text)


func set_collapsed(collapsed: bool) -> void:
	is_collapsed = collapsed
	name_input.visible = not collapsed
	address_input.visible = not collapsed
	port_input.visible = not collapsed
	host_button.visible = not collapsed
	join_button.visible = not collapsed
	collapse_button.text = "Connection" if collapsed else "Hide"


func _on_collapse_pressed() -> void:
	set_collapsed(not is_collapsed)
