extends Node
class_name InputController
## Converts local input into network intents; it does not mutate gameplay state.

var board: Node
var enabled := true
var controlled_actor_id := ""


func bind_board(new_board: Node) -> void:
	board = new_board
	TileRules.bind_board(board)


func handle_tile_clicked(tile: Vector2i) -> void:
	if not enabled or controlled_actor_id.is_empty():
		return
	NetworkService.send_intent(NetMessages.C2S_MOVE_REQUEST, {
		"actor_id": controlled_actor_id,
		"to_tile": tile,
	})


func set_enabled(new_enabled: bool) -> void:
	enabled = new_enabled


func set_controlled_actor(actor_id: String) -> void:
	controlled_actor_id = actor_id
