extends PanelContainer
class_name ChatPanel
## Sends chat text as client intent and renders chat messages.

@onready var messages: RichTextLabel = $VBoxContainer/Messages
@onready var input: LineEdit = $VBoxContainer/Input


func _ready() -> void:
	input.text_submitted.connect(_on_text_submitted)
	NetworkService.server_started.connect(_on_server_started)
	NetworkService.client_connected.connect(add_system_message.bind("connected"))
	NetworkService.client_disconnected.connect(add_system_message.bind("disconnected"))
	NetworkService.peer_joined.connect(_on_peer_joined)
	NetworkService.peer_left.connect(_on_peer_left)
	NetworkService.join_accepted.connect(_on_join_accepted)
	NetworkService.network_error.connect(add_system_message)


func append_message(message: Dictionary) -> void:
	var sender := str(message.get("from", "System"))
	var text := str(message.get("text", ""))
	messages.append_text("%s: %s\n" % [sender, text])


func add_system_message(text: String) -> void:
	print(text)
	append_message({
		"from": "System",
		"text": text,
	})


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkService.send_intent(NetMessages.C2S_CHAT_SEND, {"text": text})
	input.clear()


func _on_server_started(_port: int) -> void:
	add_system_message("server started")


func _on_peer_joined(peer_id: int) -> void:
	add_system_message("peer connected: %d" % peer_id)


func _on_peer_left(peer_id: int) -> void:
	add_system_message("peer disconnected: %d" % peer_id)


func _on_join_accepted(_payload: Dictionary) -> void:
	add_system_message("join accepted")
