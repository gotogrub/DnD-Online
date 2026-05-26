extends Node2D
class_name WorldRenderer
## Renders server snapshots onto the local ProtoCRPG board without owning state.

var board: Node
var entity_renderer: EntityRenderer


func bind_board(new_board: Node) -> void:
	board = new_board
	TileRules.bind_board(board)
	var token_root: Node = null
	if board:
		if board.has_method("get_tokens_root"):
			token_root = board.get_tokens_root() as Node
		else:
			token_root = board.get_node_or_null("Tokens")
	entity_renderer = null
	if token_root:
		entity_renderer = token_root.get_node_or_null("EntityRenderer") as EntityRenderer
	if not entity_renderer:
		entity_renderer = EntityRenderer.new()
		entity_renderer.name = "EntityRenderer"
		if token_root:
			token_root.add_child(entity_renderer)


func render_snapshot(snapshot: Dictionary) -> void:
	if not entity_renderer:
		return
	var actors: Dictionary = snapshot.get("actors", {})
	var existing := entity_renderer.get_actor_ids()
	for actor_id in actors.keys():
		entity_renderer.update_token(actors[actor_id])
		existing.erase(actor_id)
	for actor_id in existing:
		entity_renderer.remove_token(str(actor_id))


func render_delta(delta: Dictionary) -> void:
	render_snapshot(delta)
