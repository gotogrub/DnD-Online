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
	if _handle_gm_tool_click(tile):
		return
	if SessionState.is_network_mode:
		NetworkService.request_move(selected_actor_id, tile)
		return
	tile_clicked.emit(tile)
	if not can_move:
		if click_debug_enabled:
			print("move_actor: false")
		return
	var moved := SessionState.move_actor(selected_actor_id, tile)
	if click_debug_enabled:
		print("move_actor: ", moved)


func _handle_gm_tool_click(tile: Vector2i) -> bool:
	if not SessionState.is_network_mode:
		return false
	if SessionState.local_role != MvpConstants.ROLE_GM:
		return false
	if not GMToolState.is_gm_spawn_mode_active():
		return false
	var requested: bool = NetworkService.request_gm_spawn_npc(
		GMToolState.get_selected_npc_type(),
		GMToolState.get_selected_npc_name(),
		tile
	)
	if requested:
		GMToolState.clear_gm_tool()
	return true


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
