extends Node
class_name DiceRollerSingleton
## Parses and rolls bounded dice expressions on the authoritative side.

const MAX_DICE := 100
const MAX_SIDES := 1000

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func parse_expression(expression: String) -> Dictionary:
	var clean := expression.strip_edges().to_lower()
	var regex := RegEx.new()
	regex.compile("^([0-9]*)d([0-9]+)([+-][0-9]+)?$")
	var result := regex.search(clean)
	if not result:
		return {"ok": false, "error": "Use dice format NdM+K, for example 1d20+5."}
	var dice_text := result.get_string(1)
	var dice_count := 1 if dice_text.is_empty() else dice_text.to_int()
	var sides := result.get_string(2).to_int()
	var modifier_text := result.get_string(3)
	var modifier := 0 if modifier_text.is_empty() else modifier_text.to_int()
	if dice_count < 1 or dice_count > MAX_DICE:
		return {"ok": false, "error": "Dice count is out of bounds."}
	if sides < 2 or sides > MAX_SIDES:
		return {"ok": false, "error": "Dice sides are out of bounds."}
	return {
		"ok": true,
		"expression": clean,
		"dice_count": dice_count,
		"sides": sides,
		"modifier": modifier,
	}


func roll_expression(expression: String, roller_id: String = "") -> Dictionary:
	var parsed := parse_expression(expression)
	if not bool(parsed.get("ok", false)):
		return parsed
	var rolls: Array[int] = []
	var total := int(parsed["modifier"])
	for _i in range(int(parsed["dice_count"])):
		var value := _rng.randi_range(1, int(parsed["sides"]))
		rolls.append(value)
		total += value
	return {
		"ok": true,
		"roller_id": roller_id,
		"expression": parsed["expression"],
		"rolls": rolls,
		"modifier": parsed["modifier"],
		"total": total,
	}


func validate_expression(expression: String) -> bool:
	return bool(parse_expression(expression).get("ok", false))
