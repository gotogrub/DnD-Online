extends PanelContainer
class_name ChatPanel
## Sends chat text as client intent and renders chat messages.

@onready var messages: RichTextLabel = $VBoxContainer/Messages
@onready var input: LineEdit = $VBoxContainer/Input


func _ready() -> void:
	input.text_submitted.connect(_on_text_submitted)


func append_message(message: Dictionary) -> void:
	var sender := str(message.get("from", "System"))
	var text := str(message.get("text", ""))
	messages.append_text("%s: %s\n" % [sender, text])


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	NetworkService.send_intent(NetMessages.C2S_CHAT_SEND, {"text": text})
	input.clear()
