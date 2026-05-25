extends RefCounted
class_name EntityData
## Defines shared actor payload keys for client and server skeleton code.

const ACTOR_ID := "actor_id"
const KIND := "kind"
const OWNER_PEER_ID := "owner_peer_id"
const NAME := "name"
const TILE := "tile"
const SPRITE := "sprite"
const AP := "ap"
const MAX_AP := "max_ap"
const BLOCKS_TILE := "blocks_tile"
const ROLE := "role"
const PEER_ID := "peer_id"
const PLAYER_ID := "player_id"
const ACTOR_KIND := "actor_kind"


static func make_player(peer_id: int, player_id: String, player_name: String, role: String, actor_id: String = "") -> Dictionary:
	return {
		PEER_ID: peer_id,
		PLAYER_ID: player_id,
		NAME: player_name,
		ROLE: role,
		ACTOR_ID: actor_id,
	}


static func make_actor(actor_id: String, kind: String, owner_peer_id: int, actor_name: String, tile: Vector2i, sprite: String, max_ap: int, blocks_tile := true) -> Dictionary:
	return {
		ACTOR_ID: actor_id,
		KIND: kind,
		OWNER_PEER_ID: owner_peer_id,
		NAME: actor_name,
		TILE: tile,
		SPRITE: sprite,
		AP: max_ap,
		MAX_AP: max_ap,
		BLOCKS_TILE: blocks_tile,
	}


static func duplicate_payload(payload: Dictionary) -> Dictionary:
	return payload.duplicate(true)


static func empty_actor() -> Dictionary:
	return make_actor("", "", 0, "", Vector2i.ZERO, "", 0, false)
