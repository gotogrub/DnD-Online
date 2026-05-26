extends Node2D
class_name WorldRenderer
## Renders server snapshots onto the local ProtoCRPG board without owning state.

const TOKEN_SCENE := preload("res://scenes/entities/Token2D.tscn")

var board: Node
var token_root: Node2D
var token_by_actor_id := {}


func bind_board(new_board: Node) -> void:
	board = new_board
	TileRules.bind_board(board)
	token_root = null
	if board:
		if board.has_method("get_tokens_root"):
			token_root = board.get_tokens_root() as Node2D
		else:
			token_root = board.get_node_or_null("Tokens") as Node2D
	_connect_session_state()


func render_full_state(actors: Dictionary) -> void:
	if not token_root:
		return
	var stale_ids := token_by_actor_id.keys()
	for actor_id in actors.keys():
		spawn_or_update_actor(actors[actor_id])
		stale_ids.erase(actor_id)
	for actor_id in stale_ids:
		remove_actor(str(actor_id))
	print("actors rendered: ", token_by_actor_id.size())


func spawn_or_update_actor(actor: Dictionary) -> Node2D:
	if not token_root:
		return null
	var actor_id := str(actor.get(EntityData.ACTOR_ID, ""))
	if actor_id.is_empty():
		return null
	var token := token_by_actor_id.get(actor_id) as Node2D
	if not is_instance_valid(token):
		token = TOKEN_SCENE.instantiate() as Node2D
		if not token:
			return null
		token.name = actor_id
		token_root.add_child(token)
		token_by_actor_id[actor_id] = token
	if token.has_method("apply_actor_state"):
		token.apply_actor_state(actor)
	elif token.has_method("apply_actor_data"):
		token.apply_actor_data(actor)
	return token


func move_actor_visual(actor_id: String, to_tile: Vector2i, tween := true) -> void:
	var token := token_by_actor_id.get(actor_id) as Node2D
	if not is_instance_valid(token):
		token = spawn_or_update_actor(SessionState.get_actor(actor_id))
	if not is_instance_valid(token):
		return
	var world_pos := TileRules.tile_to_world(to_tile)
	if token.has_method("set_tile"):
		token.set_tile(to_tile, token.global_position)
	if token.has_method("move_to_world"):
		token.move_to_world(world_pos, tween)
	else:
		token.global_position = world_pos


func remove_actor(actor_id: String) -> void:
	var token := token_by_actor_id.get(actor_id) as Node
	token_by_actor_id.erase(actor_id)
	if is_instance_valid(token):
		token.queue_free()


func render_snapshot(snapshot: Dictionary) -> void:
	var actors: Dictionary = snapshot.get("actors", {})
	render_full_state(actors)


func render_delta(delta: Dictionary) -> void:
	render_snapshot(delta)


func _connect_session_state() -> void:
	if not SessionState.actors_changed.is_connected(_on_actors_changed):
		SessionState.actors_changed.connect(_on_actors_changed)
	if not SessionState.actor_moved.is_connected(_on_actor_moved):
		SessionState.actor_moved.connect(_on_actor_moved)
	if not SessionState.actor_removed.is_connected(_on_actor_removed):
		SessionState.actor_removed.connect(_on_actor_removed)
	if not NetworkService.move_rejected.is_connected(_on_move_rejected):
		NetworkService.move_rejected.connect(_on_move_rejected)


func _on_actors_changed() -> void:
	render_full_state(SessionState.get_actors())


func _on_actor_moved(actor_id: String, _from_tile: Vector2i, to_tile: Vector2i) -> void:
	move_actor_visual(actor_id, to_tile, true)


func _on_actor_removed(actor_id: String) -> void:
	remove_actor(actor_id)


func _on_move_rejected(payload: Dictionary) -> void:
	var actor_id := str(payload.get("actor_id", ""))
	if actor_id.is_empty():
		return
	move_actor_visual(actor_id, _as_vector2i(payload.get("authoritative_tile", Vector2i.ZERO)), false)


func _as_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
