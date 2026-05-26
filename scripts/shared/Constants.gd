extends RefCounted
class_name MvpConstants
## Shared constants for the MVP architecture shell.

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 16
const MAX_NAME_LENGTH := 14
const MAX_CHAT_LENGTH := 512
const DEFAULT_MAP_ID := "proto_world"
const MOVE_STEP_SECONDS := 0.12
const MOVE_LOCK_GRACE_SECONDS := 0.05
const MOVE_MIN_LOCK_SECONDS := 0.17
const ROLE_GM := "gm"
const ROLE_PLAYER := "player"
const ACTOR_KIND_PLAYER := "player"
const ACTOR_KIND_NPC := "npc"
const DEFAULT_MAX_AP := 9
const DEFAULT_PLAYER_SPRITE := "res://tileset/protoPlayer.png"
const DEFAULT_NPC_SPRITE := "res://tileset/protoNpc.png"
const DEFAULT_ENEMY_SPRITE := "res://tileset/protoEnemy.png"
const BOUNDARY_ATLAS_COORDS := Vector2i(0, 1)
const CARDINAL_DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const MOVE_REJECT_PEER_NOT_REGISTERED := "peer_not_registered"
const MOVE_REJECT_ACTOR_ID_EMPTY := "actor_id_empty"
const MOVE_REJECT_ACTOR_NOT_FOUND := "actor_not_found"
const MOVE_REJECT_NOT_ACTOR_OWNER := "not_actor_owner"
const MOVE_REJECT_ACTOR_ALREADY_MOVING := "actor_already_moving"
const MOVE_REJECT_TILE_MISSING := "tile_missing"
const MOVE_REJECT_TILE_NOT_WALKABLE := "tile_not_walkable"
const MOVE_REJECT_TILE_OCCUPIED := "tile_occupied"
const MOVE_REJECT_NO_PATH := "no_path"
