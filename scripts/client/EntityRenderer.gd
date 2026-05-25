extends Node2D
class_name EntityRenderer
## Creates, updates, and removes visual token nodes from authoritative actor data.

const PLAYER_TOKEN_SCENE := preload("res://scenes/entities/PlayerToken.tscn")
const NPC_TOKEN_SCENE := preload("res://scenes/entities/NpcToken.tscn")

var tokens := {}


func spawn_token(actor_data: Dictionary) -> Node:
	var actor_id := str(actor_data.get(EntityData.ACTOR_ID, ""))
	if actor_id.is_empty():
		return null
	if tokens.has(actor_id):
		return tokens[actor_id]
	var scene: PackedScene = PLAYER_TOKEN_SCENE if actor_data.get(EntityData.KIND, "") == MvpConstants.ACTOR_KIND_PLAYER else NPC_TOKEN_SCENE
	var token := scene.instantiate()
	token.name = actor_id
	add_child(token)
	tokens[actor_id] = token
	update_token(actor_data)
	return token


func update_token(actor_data: Dictionary) -> void:
	var actor_id := str(actor_data.get(EntityData.ACTOR_ID, ""))
	if actor_id.is_empty():
		return
	var token: Node = tokens.get(actor_id)
	if not token:
		token = spawn_token(actor_data)
	if token and token.has_method("apply_actor_data"):
		token.apply_actor_data(actor_data)


func remove_token(actor_id: String) -> void:
	var token: Node = tokens.get(actor_id)
	if not token:
		return
	tokens.erase(actor_id)
	token.queue_free()


func get_actor_ids() -> Array:
	return tokens.keys()
