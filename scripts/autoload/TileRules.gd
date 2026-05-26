extends Node
class_name TileRulesSingleton
## Provides tile conversion, walkability, occupancy, and path query entry points.

var board_path: NodePath
var board: Node
var layer0: TileMapLayer
var layer1: TileMapLayer


func bind_board(new_board: Node) -> void:
	board = new_board
	board_path = NodePath()
	layer0 = null
	layer1 = null
	if not board:
		return
	board_path = board.get_path()
	if board.has_method("get_layer0"):
		layer0 = board.get_layer0() as TileMapLayer
	else:
		layer0 = board.get_node_or_null("Layer0") as TileMapLayer
	if board.has_method("get_layer1"):
		layer1 = board.get_layer1() as TileMapLayer
	else:
		layer1 = board.get_node_or_null("Layer1") as TileMapLayer


func configure(new_board: Node) -> void:
	bind_board(new_board)


func world_to_tile(world_position: Vector2) -> Vector2i:
	if not layer0:
		return Vector2i.ZERO
	return layer0.local_to_map(layer0.to_local(world_position))


func tile_to_world(tile: Vector2i) -> Vector2:
	if not layer0:
		return Vector2.ZERO
	return layer0.to_global(layer0.map_to_local(tile))


func is_walkable(tile: Vector2i) -> bool:
	if not layer0:
		return false
	if layer0.get_cell_source_id(tile) == -1:
		return false
	if layer0.get_cell_atlas_coords(tile) == MvpConstants.BOUNDARY_ATLAS_COORDS:
		return false
	return not _has_blocking_layer1_tile(tile)


func is_occupied(tile: Vector2i) -> bool:
	for actor in SessionState.actors.values():
		if not bool(actor.get(EntityData.BLOCKS_TILE, true)):
			continue
		if actor.get(EntityData.TILE, Vector2i.ZERO) == tile:
			return true
	return false


func find_path(from_tile: Vector2i, to_tile: Vector2i, ignore_actor_id := "") -> Array:
	if from_tile == to_tile:
		return [from_tile] if is_walkable(from_tile) else []
	if not is_walkable(from_tile) or not is_walkable(to_tile):
		return []
	if _tile_is_occupied_by_other(to_tile, ignore_actor_id):
		return []
	var frontier: Array[Vector2i] = [from_tile]
	var came_from := {from_tile: from_tile}
	var index := 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if current == to_tile:
			break
		for direction in MvpConstants.CARDINAL_DIRECTIONS:
			var next_tile: Vector2i = current + direction
			if came_from.has(next_tile):
				continue
			if not is_walkable(next_tile):
				continue
			if next_tile != to_tile and _tile_is_occupied_by_other(next_tile, ignore_actor_id):
				continue
			came_from[next_tile] = current
			frontier.append(next_tile)
	if not came_from.has(to_tile):
		return []
	var path: Array[Vector2i] = []
	var step := to_tile
	while step != from_tile:
		path.push_front(step)
		step = came_from[step]
	path.push_front(from_tile)
	return path


func path_cost(path: Array) -> int:
	return max(path.size() - 1, 0)


func _has_blocking_layer1_tile(tile: Vector2i) -> bool:
	if not layer1:
		return false
	var candidates := [tile, tile - Vector2i(1, 1)]
	for candidate in candidates:
		if layer1.get_cell_source_id(candidate) != -1:
			return true
	return false


func _tile_is_occupied_by_other(tile: Vector2i, ignore_actor_id: String) -> bool:
	for actor in SessionState.actors.values():
		if str(actor.get(EntityData.ACTOR_ID, "")) == ignore_actor_id:
			continue
		if not bool(actor.get(EntityData.BLOCKS_TILE, true)):
			continue
		if actor.get(EntityData.TILE, Vector2i.ZERO) == tile:
			return true
	return false
