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
	NetworkService.network_error.connect(add_system_message)
	NetworkService.move_rejected.connect(_on_move_rejected)
	NetworkService.chat_message_received.connect(_on_chat_message_received)
	NetworkService.system_message_received.connect(_on_system_message_received)
	messages.scroll_following = true


func append_message(message: Dictionary) -> void:
	var kind: String = str(message.get("kind", "system"))
	if kind == "player":
		var sender: String = _clean_display_text(str(message.get("name", "Player")))
		var role: String = _clean_display_text(str(message.get("role", "")))
		var text: String = _clean_display_text(str(message.get("message", "")))
		if role.is_empty():
			messages.add_text("%s: %s\n" % [sender, text])
		else:
			messages.add_text("%s (%s): %s\n" % [sender, role, text])
		return
	var system_text: String = _clean_display_text(str(message.get("message", message.get("text", ""))))
	messages.add_text("[system] %s\n" % system_text)


func add_system_message(text: String) -> void:
	print(text)
	append_message({
		"kind": "system",
		"message": text,
	})


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if NetworkService.request_chat_message(text):
		input.clear()


func _on_server_started(_port: int) -> void:
	add_system_message("server started")


func _on_peer_joined(peer_id: int) -> void:
	if not NetworkService.is_network_server():
		return
	add_system_message("peer connected: %d" % peer_id)


func _on_peer_left(peer_id: int) -> void:
	if not NetworkService.is_network_server():
		return
	add_system_message("peer disconnected: %d" % peer_id)


func _on_move_rejected(payload: Dictionary) -> void:
	add_system_message("move rejected: %s" % str(payload.get("reason", "unknown")))


func _on_chat_message_received(payload: Dictionary) -> void:
	append_message(payload)


func _on_system_message_received(payload: Dictionary) -> void:
	append_message(payload)


func _clean_display_text(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ")
