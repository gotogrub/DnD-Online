extends Node2D
class_name ProtoBoard
## Exposes board helpers for tile conversion and token rendering.

signal tile_clicked(tile: Vector2i)

@export var local_actor_debug_enabled := true
@export var click_debug_enabled := true

@onready var layer0: TileMapLayer = $Layer0
@onready var layer1: TileMapLayer = $Layer1
@onready var tokens: Node2D = $Tokens

var world_renderer: WorldRenderer


func _ready() -> void:
	TileRules.bind_board(self)
	_setup_world_renderer()
	if local_actor_debug_enabled:
		_setup_local_debug_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click_actor_debug(get_global_mouse_position())


func get_layer0() -> TileMapLayer:
	return layer0


func get_layer1() -> TileMapLayer:
	return layer1


func tile_to_world(tile: Vector2i) -> Vector2:
	return layer0.to_global(layer0.map_to_local(tile))


func world_to_tile(world_pos: Vector2) -> Vector2i:
	return layer0.local_to_map(layer0.to_local(world_pos))


func has_tile(tile: Vector2i) -> bool:
	return layer0.get_cell_source_id(tile) != -1


func get_tokens_root() -> Node2D:
	return tokens


func get_world_renderer() -> WorldRenderer:
	return world_renderer


func _handle_click_actor_debug(world_pos: Vector2) -> void:
	var tile := world_to_tile(world_pos)
	var tile_exists := has_tile(tile)
	var walkable := tile_exists and TileRules.is_walkable(tile)
	var selected_actor_id := SessionState.selected_actor_id
	var occupied := tile_exists and TileRules.is_occupied(tile, selected_actor_id)
	var can_move := walkable and not occupied and not selected_actor_id.is_empty()
	if click_debug_enabled:
		print("clicked world_pos: ", world_pos)
		print("clicked tile: ", tile)
		print("has_tile: ", tile_exists)
		print("is_walkable: ", walkable)
		print("is_occupied: ", occupied)
		print("selected_actor_id: ", selected_actor_id)
	if SessionState.is_network_mode:
		var requested_tile := _resolve_network_move_tile(selected_actor_id, tile)
		NetworkService.request_move(selected_actor_id, requested_tile)
		return
	tile_clicked.emit(tile)
	if not can_move:
		if click_debug_enabled:
			print("move_actor: false")
		return
	var moved := SessionState.move_actor(selected_actor_id, tile)
	if click_debug_enabled:
		print("move_actor: ", moved)


func _setup_world_renderer() -> void:
	if world_renderer:
		return
	world_renderer = WorldRenderer.new()
	world_renderer.name = "WorldRenderer"
	add_child(world_renderer)
	world_renderer.bind_board(self)


func _setup_local_debug_state() -> void:
	SessionState.reset_local_debug_state()
	SessionState.create_actor("actor_player_1", MvpConstants.ACTOR_KIND_PLAYER, "Player", Vector2i(-2, 7), "player", true)
	SessionState.create_actor("actor_npc_1", MvpConstants.ACTOR_KIND_NPC, "Goblin", Vector2i(-5, 7), "npc", true)
	SessionState.selected_actor_id = "actor_player_1"
	if world_renderer:
		world_renderer.render_full_state(SessionState.get_actors())


func _resolve_network_move_tile(actor_id: String, clicked_tile: Vector2i) -> Vector2i:
	if actor_id.is_empty():
		return clicked_tile
	var actor: Dictionary = SessionState.get_actor(actor_id)
	if actor.is_empty():
		return clicked_tile
	var from_tile: Vector2i = _actor_tile(actor)
	var delta: Vector2i = clicked_tile - from_tile
	var distance: int = abs(delta.x) + abs(delta.y)
	if distance <= 1:
		return clicked_tile
	if not TileRules.has_tile(clicked_tile) or not TileRules.is_walkable(clicked_tile):
		return clicked_tile
	var candidate_tiles: Array[Vector2i] = _direction_candidates(from_tile, delta)
	for candidate_tile in candidate_tiles:
		if TileRules.is_walkable(candidate_tile) and not TileRules.is_occupied(candidate_tile, actor_id):
			if click_debug_enabled:
				print("network move target clamped: ", clicked_tile, " -> ", candidate_tile)
			return candidate_tile
	if not candidate_tiles.is_empty():
		if click_debug_enabled:
			print("network move target blocked, asking server: ", candidate_tiles[0])
		return candidate_tiles[0]
	return clicked_tile


func _direction_candidates(from_tile: Vector2i, delta: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var x_step: int = _axis_step(delta.x)
	var y_step: int = _axis_step(delta.y)
	if abs(delta.x) >= abs(delta.y):
		if x_step != 0:
			candidates.append(from_tile + Vector2i(x_step, 0))
		if y_step != 0:
			candidates.append(from_tile + Vector2i(0, y_step))
	else:
		if y_step != 0:
			candidates.append(from_tile + Vector2i(0, y_step))
		if x_step != 0:
			candidates.append(from_tile + Vector2i(x_step, 0))
	return candidates


func _axis_step(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _actor_tile(actor: Dictionary) -> Vector2i:
	var tile_value: Variant = actor.get(EntityData.TILE, Vector2i.ZERO)
	if tile_value is Vector2i:
		return tile_value
	if tile_value is Vector2:
		return Vector2i(int(tile_value.x), int(tile_value.y))
	if tile_value is Dictionary:
		return Vector2i(int(tile_value.get("x", 0)), int(tile_value.get("y", 0)))
	if tile_value is Array and tile_value.size() >= 2:
		return Vector2i(int(tile_value[0]), int(tile_value[1]))
	return Vector2i.ZERO
