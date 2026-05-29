extends Node2D
class_name WorldContainerToken
## Displays a server-authored world loot container without physics or collision queries.

const SPRITE_OFFSET := Vector2(0, -20)
const NAME_LABEL_WIDTH := 220.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

var container_id := ""
var current_tile := Vector2i.ZERO


func _ready() -> void:
	name_label.z_as_relative = false
	name_label.z_index = 4096
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.visible = false
	_center_name_label()


func apply_container_state(container: Dictionary) -> void:
	container_id = str(container.get(EntityData.CONTAINER_ID, ""))
	name = container_id if not container_id.is_empty() else "WorldContainer"
	name_label.text = str(container.get(EntityData.NAME, "Loot"))
	var sprite_path: String = _resolve_sprite_path(str(container.get(EntityData.SPRITE, "")))
	if not sprite_path.is_empty():
		sprite.texture = load(sprite_path)
		_apply_sprite_region(sprite_path)
	sprite.centered = true
	sprite.offset = SPRITE_OFFSET
	sprite.scale = Vector2(1.0, 1.0)
	var tile: Vector2i = _as_vector2i(container.get(EntityData.TILE, Vector2i.ZERO))
	set_tile(tile, TileRules.tile_to_world(tile))


func set_tile(tile: Vector2i, world_pos: Vector2) -> void:
	current_tile = tile
	global_position = world_pos


func _resolve_sprite_path(sprite_key: String) -> String:
	if not sprite_key.is_empty() and ResourceLoader.exists(sprite_key):
		return sprite_key
	if ResourceLoader.exists(MvpConstants.DEFAULT_WORLD_CONTAINER_SPRITE):
		return MvpConstants.DEFAULT_WORLD_CONTAINER_SPRITE
	if ResourceLoader.exists(MvpConstants.FALLBACK_ITEM_ICON):
		return MvpConstants.FALLBACK_ITEM_ICON
	return ""


func _apply_sprite_region(sprite_path: String) -> void:
	if sprite_path == MvpConstants.DEFAULT_WORLD_CONTAINER_SPRITE:
		sprite.region_enabled = true
		sprite.region_rect = MvpConstants.DEFAULT_WORLD_CONTAINER_SPRITE_REGION
		return
	sprite.region_enabled = false


func _center_name_label() -> void:
	name_label.offset_left = -NAME_LABEL_WIDTH * 0.5
	name_label.offset_top = -72.0
	name_label.offset_right = NAME_LABEL_WIDTH * 0.5
	name_label.offset_bottom = -48.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
