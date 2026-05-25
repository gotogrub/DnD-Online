extends RefCounted
class_name EntityService
## Creates and updates server-side actor records after validation by higher-level services.

var _actor_sequence := 1


func create_player_actor(player_id: String, tile: Vector2i, peer_id := 0, actor_name := "") -> Dictionary:
	var actor_id := _next_actor_id()
	var name := actor_name if not actor_name.is_empty() else player_id
	var actor := EntityData.make_actor(
		actor_id,
		MvpConstants.ACTOR_KIND_PLAYER,
		peer_id,
		name,
		tile,
		MvpConstants.DEFAULT_PLAYER_SPRITE,
		MvpConstants.DEFAULT_MAX_AP,
		true
	)
	SessionState.set_actor(actor)
	return actor


func create_npc_actor(npc_type: String, tile: Vector2i, name: String = "") -> Dictionary:
	var actor_id := _next_actor_id()
	var actor_name := name if not name.is_empty() else npc_type.capitalize()
	var enemy_types := ["enemy", "goblin", "skeleton"]
	var sprite := MvpConstants.DEFAULT_ENEMY_SPRITE if enemy_types.has(npc_type.to_lower()) else MvpConstants.DEFAULT_NPC_SPRITE
	var actor := EntityData.make_actor(
		actor_id,
		MvpConstants.ACTOR_KIND_NPC,
		0,
		actor_name,
		tile,
		sprite,
		MvpConstants.DEFAULT_MAX_AP,
		true
	)
	SessionState.set_actor(actor)
	return actor


func remove_actor(actor_id: String) -> void:
	SessionState.remove_actor(actor_id)


func _next_actor_id() -> String:
	var actor_id := "actor_%d" % _actor_sequence
	_actor_sequence += 1
	while SessionState.has_actor(actor_id):
		actor_id = "actor_%d" % _actor_sequence
		_actor_sequence += 1
	return actor_id
