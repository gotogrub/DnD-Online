extends Resource
class_name GridPosition
## Lightweight value object for tile coordinates passed through MVP skeleton APIs.

@export var tile := Vector2i.ZERO


func set_tile(new_tile: Vector2i) -> void:
	tile = new_tile


func to_payload() -> Dictionary:
	return {
		"x": tile.x,
		"y": tile.y,
	}


static func from_payload(payload: Dictionary) -> GridPosition:
	var position := GridPosition.new()
	position.tile = Vector2i(int(payload.get("x", 0)), int(payload.get("y", 0)))
	return position
