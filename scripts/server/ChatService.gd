extends RefCounted
class_name ChatService
## Handles plain chat messages before command routing or broadcast.


func submit_message(peer_id: int, text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.length() > MvpConstants.MAX_CHAT_LENGTH:
		clean = clean.left(MvpConstants.MAX_CHAT_LENGTH)
	var player := SessionState.get_player(peer_id)
	var message := {
		"from_peer_id": peer_id,
		"from": player.get(EntityData.NAME, "Peer %d" % peer_id),
		"role": player.get(EntityData.ROLE, ""),
		"text": clean,
		"system": false,
		"server_time": Time.get_unix_time_from_system(),
	}
	SessionState.add_chat_message(message)
	return message


func build_system_message(text: String) -> Dictionary:
	var message := {
		"from_peer_id": 0,
		"from": "System",
		"role": "system",
		"text": text,
		"system": true,
		"server_time": Time.get_unix_time_from_system(),
	}
	SessionState.add_chat_message(message)
	return message
