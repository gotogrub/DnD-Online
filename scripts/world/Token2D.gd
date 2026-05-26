extends Node2D
class_name Token2DView
## Displays a server-authored actor record as a simple isometric token.

signal movement_started(actor_id: String)
signal movement_finished(actor_id: String)

@export var move_seconds: float = MvpConstants.MOVE_STEP_SECONDS

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

var actor_id := ""
var actor_kind := ""
var current_tile := Vector2i.ZERO
var is_moving := false
var move_tween: Tween


func _ready() -> void:
	name_label.z_as_relative = false
	name_label.z_index = 4096
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_actor_state(actor: Dictionary) -> void:
	actor_id = str(actor.get(EntityData.ACTOR_ID, ""))
	actor_kind = str(actor.get(EntityData.KIND, ""))
	var display_name := str(actor.get(EntityData.NAME, actor_id))
	if actor_kind.is_empty():
		name_label.text = display_name
	else:
		name_label.text = "%s (%s)" % [display_name, actor_kind]
	var sprite_path := _resolve_sprite_path(str(actor.get(EntityData.SPRITE, "")), actor_kind)
	if not sprite_path.is_empty():
		sprite.texture = load(sprite_path)
		_apply_sprite_origin(sprite_path, actor_kind)
	var tile: Vector2i = actor.get(EntityData.TILE, Vector2i.ZERO)
	set_tile(tile, TileRules.tile_to_world(tile))


func apply_actor_data(actor_data: Dictionary) -> void:
	apply_actor_state(actor_data)


func set_tile(tile: Vector2i, world_pos: Vector2) -> void:
	current_tile = tile
	global_position = world_pos


func move_to_world(world_pos: Vector2, tween := true) -> void:
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	if not tween or move_seconds <= 0.0:
		global_position = world_pos
		_finish_movement()
		return
	_begin_movement()
	move_tween = create_tween()
	move_tween.tween_property(self, "global_position", world_pos, move_seconds)
	move_tween.finished.connect(_finish_movement)


func move_along_path(tile_path: Array[Vector2i], world_points: Array[Vector2], tween := true) -> void:
	if tile_path.is_empty() or world_points.is_empty():
		return
	current_tile = _as_vector2i(tile_path[tile_path.size() - 1])
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	if not tween or move_seconds <= 0.0 or world_points.size() == 1:
		global_position = world_points[world_points.size() - 1]
		_finish_movement()
		return
	_begin_movement()
	move_tween = create_tween()
	for index in range(1, world_points.size()):
		move_tween.tween_property(self, "global_position", world_points[index], move_seconds)
	move_tween.finished.connect(_finish_movement)


func is_visual_moving() -> bool:
	return is_moving


func _begin_movement() -> void:
	if is_moving:
		return
	is_moving = true
	movement_started.emit(actor_id)


func _finish_movement() -> void:
	if not is_moving:
		return
	is_moving = false
	movement_finished.emit(actor_id)


func _resolve_sprite_path(sprite_key: String, kind: String) -> String:
	if sprite_key == MvpConstants.ACTOR_KIND_PLAYER or sprite_key == "player":
		return MvpConstants.DEFAULT_PLAYER_SPRITE
	if sprite_key == MvpConstants.ACTOR_KIND_NPC or sprite_key == "npc":
		return MvpConstants.DEFAULT_NPC_SPRITE
	if sprite_key == "enemy":
		return MvpConstants.DEFAULT_ENEMY_SPRITE
	if not sprite_key.is_empty():
		return sprite_key
	if kind == MvpConstants.ACTOR_KIND_PLAYER:
		return MvpConstants.DEFAULT_PLAYER_SPRITE
	if kind == MvpConstants.ACTOR_KIND_NPC:
		return MvpConstants.DEFAULT_NPC_SPRITE
	return ""


func _apply_sprite_origin(sprite_path: String, kind: String) -> void:
	sprite.centered = true
	if kind == MvpConstants.ACTOR_KIND_PLAYER or kind == MvpConstants.ACTOR_KIND_NPC:
		sprite.offset = Vector2(0, -24)
		return
	if sprite_path == MvpConstants.DEFAULT_PLAYER_SPRITE or sprite_path == MvpConstants.DEFAULT_NPC_SPRITE:
		sprite.offset = Vector2(0, -24)
		return
	sprite.offset = Vector2.ZERO


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
