extends Node2D
class_name Token2DView
## Displays a server-authored actor record as a simple isometric token.

@export var move_seconds := 0.12

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

var actor_id := ""
var actor_kind := ""
var current_tile := Vector2i.ZERO
var move_tween: Tween


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
		return
	move_tween = create_tween()
	move_tween.tween_property(self, "global_position", world_pos, move_seconds)


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
