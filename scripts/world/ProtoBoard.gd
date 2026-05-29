extends Node2D
class_name ProtoBoard
## Exposes board helpers for tile conversion and token rendering.

signal tile_clicked(tile: Vector2i)

@export var local_actor_debug_enabled := true
@export var click_debug_enabled := true
@export_file("*.json") var map_config_path := "res://data/maps/proto_world.json"
@export var default_background_color := Color.BLACK

@onready var map_background: Sprite2D = $MapBackground
@onready var layer0: TileMapLayer = $Layer0
@onready var layer1: TileMapLayer = $Layer1
@onready var tokens: Node2D = $Tokens

var world_renderer: WorldRenderer


func _ready() -> void:
	RenderingServer.set_default_clear_color(default_background_color)
	_apply_map_config()
	TileRules.bind_board(self)
	_setup_world_renderer()
	if local_actor_debug_enabled and not SessionState.is_network_mode:
		_setup_local_debug_state()
	elif world_renderer:
		world_renderer.render_full_state(SessionState.get_actors())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var additive_select: bool = event.shift_pressed
		_handle_click_actor_debug(get_global_mouse_position(), additive_select)


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


func _apply_map_config() -> void:
	var config: Dictionary = _load_map_config()
	if config.is_empty():
		_apply_background({})
		return
	var map_id: String = str(config.get("map_id", MvpConstants.DEFAULT_MAP_ID)).strip_edges()
	if not map_id.is_empty():
		SessionState.map_id = map_id
	var background_id: String = str(config.get("background_id", "black")).strip_edges().to_lower()
	var backgrounds: Dictionary = _dictionary_from_variant(config.get("backgrounds", {}))
	var background: Dictionary = {}
	if backgrounds.has(background_id):
		background = _dictionary_from_variant(backgrounds.get(background_id, {}))
	_apply_background(background)


func _load_map_config() -> Dictionary:
	if map_config_path.is_empty() or not FileAccess.file_exists(map_config_path):
		return {}
	var file: FileAccess = FileAccess.open(map_config_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read map config: %s" % map_config_path)
		return {}
	var parsed_data: Variant = JSON.parse_string(file.get_as_text())
	if parsed_data is Dictionary:
		return (parsed_data as Dictionary).duplicate(true)
	push_warning("Map config is not a dictionary: %s" % map_config_path)
	return {}


func _apply_background(background: Dictionary) -> void:
	var background_color: Color = Color.from_string(str(background.get("color", "#000000")), default_background_color)
	RenderingServer.set_default_clear_color(background_color)
	if not map_background:
		return
	var texture_path: String = str(background.get("texture", "")).strip_edges()
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		map_background.texture = null
		map_background.visible = false
		return
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		map_background.texture = null
		map_background.visible = false
		return
	map_background.texture = texture
	map_background.visible = true
	map_background.position = _vector2_from_variant(background.get("position", map_background.position), map_background.position)
	var scale_value: Variant = background.get("scale", map_background.scale)
	if scale_value is int or scale_value is float:
		var uniform_scale: float = float(scale_value)
		map_background.scale = Vector2(uniform_scale, uniform_scale)
	else:
		map_background.scale = _vector2_from_variant(scale_value, map_background.scale)
	map_background.modulate.a = clampf(float(background.get("opacity", 1.0)), 0.0, 1.0)


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		var vector_value: Vector2i = value
		return Vector2(vector_value.x, vector_value.y)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return Vector2(float(dictionary_value.get("x", fallback.x)), float(dictionary_value.get("y", fallback.y)))
	if value is Array:
		var array_value: Array = value
		if array_value.size() >= 2:
			return Vector2(float(array_value[0]), float(array_value[1]))
	return fallback


func _handle_click_actor_debug(world_pos: Vector2, additive_select := false) -> void:
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
	if SessionState.is_network_mode and not SessionState.is_joined:
		if click_debug_enabled:
			print("map click ignored: character not selected")
		return
	if _handle_gm_tool_click(tile, additive_select):
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


func _handle_gm_tool_click(tile: Vector2i, additive_select := false) -> bool:
	if not SessionState.is_network_mode:
		return false
	if SessionState.local_role != MvpConstants.ROLE_GM:
		return false
	if GMToolState.is_gm_spawn_mode_active():
		NetworkService.request_gm_spawn_npc(
			GMToolState.get_selected_npc_type(),
			GMToolState.get_selected_npc_name(),
			tile
		)
		return true
	if GMToolState.is_select_actor_mode_active():
		_select_gm_actor_at_tile(tile, additive_select)
		return true
	if GMToolState.is_move_selected_mode_active():
		if not GMToolState.can_move_selected_actor():
			print("gm move selected ignored: select exactly one actor")
			return true
		var selected_actor_id: String = GMToolState.get_selected_actor_id()
		NetworkService.request_move(selected_actor_id, tile)
		return true
	return false


func _select_gm_actor_at_tile(tile: Vector2i, additive_select := false) -> void:
	var actor_id: String = SessionState.find_actor_at_tile(tile)
	if actor_id.is_empty():
		if not additive_select:
			GMToolState.clear_selected_actor()
		print("gm select actor: no actor at tile %s" % str(tile))
		return
	var actor: Dictionary = SessionState.get_actor(actor_id)
	if additive_select:
		GMToolState.toggle_selected_actor(actor_id)
	else:
		GMToolState.set_selected_actor(actor_id)
	print("gm selected actor: %s %s" % [
		str(actor.get(EntityData.NAME, actor_id)),
		actor_id,
	])


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
