extends Node2D
class_name ProtoBoard
## Exposes board helpers for tile conversion and token rendering.

signal tile_clicked(tile: Vector2i)

@export var smoke_test_tile := Vector2i(5, 5)
@export var smoke_token_scene: PackedScene
@export var spawn_smoke_token := true
@export var click_debug_enabled := true
@export_range(0.0, 0.15, 0.01) var smoke_move_seconds := 0.12

@onready var layer0: TileMapLayer = $Layer0
@onready var layer1: TileMapLayer = $Layer1
@onready var tokens: Node2D = $Tokens

var smoke_token: Node2D
var smoke_move_tween: Tween


func _ready() -> void:
	TileRules.bind_board(self)
	if spawn_smoke_token:
		_spawn_smoke_token()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click_smoke_test(get_global_mouse_position())


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


func _spawn_smoke_token() -> void:
	if not smoke_token_scene:
		return
	var token := smoke_token_scene.instantiate()
	smoke_token = token as Node2D
	if not smoke_token:
		token.queue_free()
		return
	token.name = "SmokeToken"
	tokens.add_child(token)
	if token.has_method("apply_actor_data"):
		token.apply_actor_data({
			EntityData.ACTOR_ID: "smoke_token",
			EntityData.NAME: "Token",
			EntityData.KIND: MvpConstants.ACTOR_KIND_PLAYER,
			EntityData.TILE: smoke_test_tile,
			EntityData.SPRITE: MvpConstants.DEFAULT_PLAYER_SPRITE,
		})
	else:
		token.global_position = tile_to_world(smoke_test_tile)


func _handle_click_smoke_test(world_pos: Vector2) -> void:
	var tile := world_to_tile(world_pos)
	var tile_exists := has_tile(tile)
	var walkable := tile_exists and TileRules.is_walkable(tile)
	if click_debug_enabled:
		print("clicked world_pos: ", world_pos)
		print("clicked tile: ", tile)
		print("has_tile: ", tile_exists)
		print("is_walkable: ", walkable)
	tile_clicked.emit(tile)
	if walkable:
		_move_smoke_token_to_tile(tile)


func _move_smoke_token_to_tile(tile: Vector2i) -> void:
	if not is_instance_valid(smoke_token):
		_spawn_smoke_token()
	if not is_instance_valid(smoke_token):
		return
	var target_position := tile_to_world(tile)
	if smoke_move_tween and smoke_move_tween.is_valid():
		smoke_move_tween.kill()
	if smoke_move_seconds <= 0.0:
		smoke_token.global_position = target_position
		return
	smoke_move_tween = create_tween()
	smoke_move_tween.tween_property(smoke_token, "global_position", target_position, smoke_move_seconds)
