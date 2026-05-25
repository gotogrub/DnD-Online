extends Node2D
class_name WorldRenderer
## Renders server snapshots onto the local ProtoCRPG board without owning state.

var board: Node
var entity_renderer: EntityRenderer


func bind_board(new_board: Node) -> void:
	board = new_board
	TileRules.configure(board)
	entity_renderer = board.get_node_or_null("Tokens/EntityRenderer") as EntityRenderer
	if not entity_renderer:
		entity_renderer = EntityRenderer.new()
		entity_renderer.name = "EntityRenderer"
		var token_root := board.get_node_or_null("Tokens")
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
