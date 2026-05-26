extends Node
class_name DiceRollerSingleton
## Parses and rolls bounded dice expressions on the authoritative side.

const MAX_DICE := 100
const MAX_SIDES := 1000
const MIN_SIDES := 2
const MAX_MODIFIER := 10000

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func parse_expression(expression: String) -> Dictionary:
	var clean: String = expression.strip_edges().to_lower().replace(" ", "")
	if clean.is_empty():
		return _parse_error("invalid expression", clean)
	var dice_count: int = 1
	var sides: int = 0
	var modifier: int = 0
	if clean.is_valid_int():
		sides = clean.to_int()
	else:
		var regex: RegEx = RegEx.new()
		var compile_error: Error = regex.compile("^([0-9]*)d([0-9]+)([+-][0-9]+)?$")
		if compile_error != OK:
			return _parse_error("invalid expression", clean)
		var result: RegExMatch = regex.search(clean)
		if result == null:
			return _parse_error("invalid expression", clean)
		var dice_text: String = result.get_string(1)
		dice_count = 1 if dice_text.is_empty() else dice_text.to_int()
		sides = result.get_string(2).to_int()
		var modifier_text: String = result.get_string(3)
		modifier = 0 if modifier_text.is_empty() else modifier_text.to_int()
	if dice_count < 1 or dice_count > MAX_DICE:
		return _parse_error("dice count must be between 1 and 100", clean)
	if sides < MIN_SIDES or sides > MAX_SIDES:
		return _parse_error("dice sides must be between 2 and 1000", clean)
	if modifier < -MAX_MODIFIER or modifier > MAX_MODIFIER:
		return _parse_error("modifier must be between -10000 and 10000", clean)
	var normalized_modifier_text: String = ""
	if modifier > 0:
		normalized_modifier_text = "+%d" % modifier
	elif modifier < 0:
		normalized_modifier_text = str(modifier)
	var normalized_expr: String = "%dd%d%s" % [dice_count, sides, normalized_modifier_text]
	return {
		"ok": true,
		"error": "",
		"expr": clean,
		"normalized_expr": normalized_expr,
		"count": dice_count,
		"sides": sides,
		"rolls": [],
		"modifier": modifier,
		"total": 0,
	}


func roll_expression(expression: String, roller_id: String = "") -> Dictionary:
	var parsed: Dictionary = parse_expression(expression)
	if not bool(parsed.get("ok", false)):
		return parsed
	var rolls: Array[int] = []
	var total: int = int(parsed["modifier"])
	for _i in range(int(parsed["count"])):
		var value: int = _rng.randi_range(1, int(parsed["sides"]))
		rolls.append(value)
		total += value
	parsed["roller_id"] = roller_id
	parsed["rolls"] = rolls
	parsed["total"] = total
	return parsed


func validate_expression(expression: String) -> bool:
	return bool(parse_expression(expression).get("ok", false))


func _parse_error(error: String, expr: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"expr": expr,
		"normalized_expr": "",
		"count": 0,
		"sides": 0,
		"rolls": [],
		"modifier": 0,
		"total": 0,
	}
