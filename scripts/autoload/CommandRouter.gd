extends Node
class_name CommandRouterSingleton
## Parses chat text and routes future GM/player commands to server services.

const COMMAND_HELP := "gm"
const COMMAND_ROLL := "roll"
const COMMAND_SPAWN := "spawn"
const COMMAND_MOVE := "move"
const COMMAND_ENCOUNTER := "enc"
const COMMAND_INIT := "init"
const COMMAND_TURN := "turn"


func parse_chat_text(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return {"type": "empty"}
	if not is_command(clean):
		return {"type": "chat", "text": clean}
	var parts := _tokenize(clean.substr(1))
	if parts.is_empty():
		return {"type": "error", "error": "Empty command."}
	var command := str(parts[0]).to_lower()
	return {
		"type": "command",
		"command": command,
		"args": parts.slice(1),
		"raw": clean,
	}


func route_chat_message(peer_id: int, text: String) -> Dictionary:
	var parsed := parse_chat_text(text)
	parsed["peer_id"] = peer_id
	return parsed


func is_command(text: String) -> bool:
	return text.strip_edges().begins_with("/")


func _tokenize(text: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	var in_quotes := false
	for i in range(text.length()):
		var character := text.substr(i, 1)
		if character == "\"":
			in_quotes = not in_quotes
			continue
		if character == " " and not in_quotes:
			if not current.is_empty():
				tokens.append(current)
				current = ""
			continue
		current += character
	if not current.is_empty():
		tokens.append(current)
	return tokens
