extends PanelContainer
class_name ConnectPanel
## Collects local connection settings and calls NetworkService lifecycle methods.

signal back_requested()

const MODE_HOST := "host"
const MODE_JOIN := "join"

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var address_input: LineEdit = $VBoxContainer/AddressInput
@onready var port_input: SpinBox = $VBoxContainer/PortInput
@onready var host_button: Button = $VBoxContainer/Buttons/HostButton
@onready var join_button: Button = $VBoxContainer/Buttons/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var collapse_button: Button = $VBoxContainer/CollapseButton

var is_collapsed := false
var mode := MODE_HOST


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	collapse_button.pressed.connect(_on_back_pressed)
	NetworkService.server_started.connect(_on_server_started)
	NetworkService.client_connected.connect(_set_connected)
	NetworkService.client_disconnected.connect(_set_disconnected)
	NetworkService.join_accepted.connect(_on_join_accepted)
	NetworkService.network_error.connect(_set_status)
	set_mode(MODE_HOST)


func _on_host_pressed() -> void:
	NetworkService.player_name = ""
	NetworkService.start_server(int(port_input.value))


func _on_join_pressed() -> void:
	if NetworkService.connect_to_server(address_input.text, int(port_input.value), ""):
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
	if collapsed:
		title_label.text = "Connection"
		address_input.visible = false
		port_input.visible = false
		host_button.visible = false
		join_button.visible = false
		collapse_button.visible = false
		return
	set_mode(mode)


func set_mode(new_mode: String) -> void:
	mode = MODE_JOIN if new_mode == MODE_JOIN else MODE_HOST
	is_collapsed = false
	title_label.text = "Join Game" if mode == MODE_JOIN else "Host Game"
	address_input.visible = mode == MODE_JOIN
	port_input.visible = true
	host_button.visible = mode == MODE_HOST
	join_button.visible = mode == MODE_JOIN
	collapse_button.visible = true
	collapse_button.text = "Back"
	status_label.text = "Ready"


func _on_back_pressed() -> void:
	back_requested.emit()
