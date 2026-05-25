extends RefCounted
class_name MvpConstants
## Shared constants for the MVP architecture shell.

const DEFAULT_PORT := 7000
const MAX_PLAYERS := 16
const MAX_NAME_LENGTH := 32
const MAX_CHAT_LENGTH := 512
const DEFAULT_MAP_ID := "proto_world"
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
