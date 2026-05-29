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
const SPRITE_PLAYER_HUMAN := "res://tileset/p_human.png"
const SPRITE_PLAYER_ELF := "res://tileset/p_elf.png"
const SPRITE_PLAYER_ORC := "res://tileset/p_orc.png"
const SPRITE_PLAYER_DWARF := "res://tileset/p_dwarf.png"
const SPRITE_NPC_GOBLIN := "res://tileset/goblin.png"
const SPRITE_NPC_RAIDER := "res://tileset/enemy_heavy_guard.png"
const SPRITE_NPC_GUARD := "res://tileset/guard_strong.png"
const SPRITE_NPC_MERCHANT := "res://tileset/merchant.png"
const DEFAULT_PLAYER_SPRITE := SPRITE_PLAYER_HUMAN
const DEFAULT_NPC_SPRITE := SPRITE_NPC_GOBLIN
const DEFAULT_ENEMY_SPRITE := SPRITE_NPC_RAIDER
const DICE_ROLL_SOUND := "res://sound/dices_roll.mp3"
const DICE_ROLL_VOLUME_DB := -18.0
const DEFAULT_ITEM_ICON := "res://tileset/item_bag.png"
const FALLBACK_ITEM_ICON := "res://tileset/dices_bag.png"
const MAX_ITEM_GIVE_QUANTITY := 9999
const CLIENT_IDENTITY_PATH := "user://client_identity.json"
const SERVER_DATA_ROOT := "user://server_data"
const SERVER_CHARACTERS_DIR := "user://server_data/characters"
const SERVER_OWNERS_DIR := "user://server_data/owners"
const DEFAULT_BASE_STAT := 10
const CHARACTER_STAT_MIN := 6
const CHARACTER_STAT_MAX := 16
const CHARACTER_POINT_BUY_POINTS := 8
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
