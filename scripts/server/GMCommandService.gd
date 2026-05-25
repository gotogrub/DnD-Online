extends RefCounted
class_name GMCommandService
## Owns GM-only command entry points such as spawn, forced movement, and encounter control.

var entity_service: EntityService
var movement_service: MovementService
var encounter_service: EncounterService
var chat_service: ChatService


func _init(p_entity_service: EntityService = null, p_movement_service: MovementService = null, p_encounter_service: EncounterService = null, p_chat_service: ChatService = null) -> void:
	entity_service = p_entity_service if p_entity_service else EntityService.new()
	movement_service = p_movement_service if p_movement_service else MovementService.new()
	encounter_service = p_encounter_service if p_encounter_service else EncounterService.new()
	chat_service = p_chat_service if p_chat_service else ChatService.new()


func can_run_gm_command(peer_id: int) -> bool:
	return SessionState.is_gm(peer_id)


func handle_command(peer_id: int, command: Dictionary) -> Dictionary:
	var name := str(command.get("command", "")).to_lower()
	var args: Array = command.get("args", [])
	if name == CommandRouter.COMMAND_ROLL:
		var roll_expression := _join_args(args)
		return {"ok": true, "type": "roll", "result": DiceRoller.roll_expression(roll_expression, str(peer_id))}
	if not can_run_gm_command(peer_id):
		return {"ok": false, "error": "GM permissions required."}
	match name:
		CommandRouter.COMMAND_HELP:
			return {"ok": true, "type": "help", "lines": get_help()}
		CommandRouter.COMMAND_SPAWN:
			return _spawn(args)
		CommandRouter.COMMAND_MOVE:
			return _move(args)
		CommandRouter.COMMAND_ENCOUNTER:
			return _encounter(args)
		CommandRouter.COMMAND_INIT:
			return _initiative(args)
		CommandRouter.COMMAND_TURN:
			return _turn(args)
		_:
			return {"ok": false, "error": "Unknown command."}


func get_help() -> Array:
	return [
		"/spawn goblin 12 7",
		"/spawn npc \"Guard\" 12 7",
		"/move actor_1 13 8",
		"/roll 1d20+5",
		"/enc start",
		"/enc end",
		"/init actor_1 15",
		"/turn next",
	]


func _spawn(args: Array) -> Dictionary:
	if args.size() < 3:
		return {"ok": false, "error": "Usage: /spawn npc_type x y"}
	var npc_type := str(args[0])
	var x := int(args[args.size() - 2])
	var y := int(args[args.size() - 1])
	var name := ""
	if args.size() > 3:
		name = _join_args(args, 1, args.size() - 2)
	var tile := Vector2i(x, y)
	if not TileRules.is_walkable(tile) or TileRules.is_occupied(tile):
		return {"ok": false, "error": "Spawn tile is blocked."}
	var actor := entity_service.create_npc_actor(npc_type, tile, name)
	return {"ok": true, "type": "spawn", "actor": actor}


func _move(args: Array) -> Dictionary:
	if args.size() < 3:
		return {"ok": false, "error": "Usage: /move actor_id x y"}
	var actor_id := str(args[0])
	var tile := Vector2i(int(args[1]), int(args[2]))
	var move_result := movement_service.build_move_result(actor_id, tile)
	if bool(move_result.get("ok", false)):
		movement_service.apply_move(move_result)
	return {"ok": bool(move_result.get("ok", false)), "type": "move", "move": move_result, "error": move_result.get("error", "")}


func _encounter(args: Array) -> Dictionary:
	if args.is_empty():
		return {"ok": false, "error": "Usage: /enc start|end"}
	match str(args[0]).to_lower():
		"start":
			return {"ok": true, "type": "encounter", "state": encounter_service.start_encounter()}
		"end":
			return {"ok": true, "type": "encounter", "state": encounter_service.end_encounter()}
		_:
			return {"ok": false, "error": "Unknown encounter command."}


func _initiative(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"ok": false, "error": "Usage: /init actor_id value"}
	return {
		"ok": true,
		"type": "encounter",
		"state": encounter_service.set_initiative(str(args[0]), int(args[1])),
	}


func _turn(args: Array) -> Dictionary:
	if args.is_empty() or str(args[0]).to_lower() != "next":
		return {"ok": false, "error": "Usage: /turn next"}
	return {"ok": true, "type": "encounter", "state": encounter_service.next_turn()}


func _join_args(args: Array, start := 0, end := -1) -> String:
	var last := args.size() if end < 0 else min(end, args.size())
	var text := ""
	for index in range(start, last):
		if not text.is_empty():
			text += " "
		text += str(args[index])
	return text
