extends Node2D
class_name TokenView
## Displays a server-authored actor record as a simple isometric token.

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

var actor_id := ""


func apply_actor_data(actor_data: Dictionary) -> void:
	actor_id = str(actor_data.get(EntityData.ACTOR_ID, ""))
	name_label.text = str(actor_data.get(EntityData.NAME, actor_id))
	var sprite_path := str(actor_data.get(EntityData.SPRITE, ""))
	if not sprite_path.is_empty():
		sprite.texture = load(sprite_path)
	var tile: Vector2i = actor_data.get(EntityData.TILE, Vector2i.ZERO)
	global_position = TileRules.tile_to_world(tile)
