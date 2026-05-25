extends Node2D
class_name ProtoBoard
## Exposes board helpers for tile conversion and token rendering.

signal tile_clicked(tile: Vector2i)

@onready var layer0: TileMapLayer = $Layer0
@onready var layer1: TileMapLayer = $Layer1
@onready var tokens: Node2D = $Tokens


func _ready() -> void:
	TileRules.configure(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(world_to_tile(get_global_mouse_position()))


func world_to_tile(world_position: Vector2) -> Vector2i:
	return layer0.local_to_map(layer0.to_local(world_position))


func tile_to_world(tile: Vector2i) -> Vector2:
	return layer0.to_global(layer0.map_to_local(tile))
