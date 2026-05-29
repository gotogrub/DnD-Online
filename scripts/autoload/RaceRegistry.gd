extends Node
class_name RaceRegistrySingleton
## Stores MVP race templates used by CharacterService; this is data, not gameplay state.

const BASE_STAT_KEYS: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]

var races: Dictionary = {}


func _ready() -> void:
	_register_default_races()


func get_races() -> Dictionary:
	return races.duplicate(true)


func get_race(race_id: String) -> Dictionary:
	var normalized_race_id: String = normalize_race_id(race_id)
	var race: Dictionary = races.get(normalized_race_id, races.get("human", {})) as Dictionary
	return race.duplicate(true)


func has_race(race_id: String) -> bool:
	return races.has(normalize_race_id(race_id))


func normalize_race_id(race_id: String) -> String:
	var normalized_race_id: String = race_id.strip_edges().to_lower()
	if normalized_race_id.is_empty() or not races.has(normalized_race_id):
		return "human"
	return normalized_race_id


func base_stats(default_value: int = -1) -> Dictionary:
	if default_value < 0:
		default_value = MvpConstants.DEFAULT_BASE_STAT
	var stats: Dictionary = {}
	for stat_key: String in BASE_STAT_KEYS:
		stats[stat_key] = default_value
	return stats


func normalize_base_stats(base_stats_data: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	for stat_key: String in BASE_STAT_KEYS:
		stats[stat_key] = int(base_stats_data.get(stat_key, MvpConstants.DEFAULT_BASE_STAT))
	return stats


func _register_default_races() -> void:
	races = {
		"human": _make_race(
			"human",
			"Human",
			"Reliable, flexible, and easy to fit into any adventuring party.",
			{},
			0,
			0,
			MvpConstants.SPRITE_PLAYER_HUMAN
		),
		"elf": _make_race(
			"elf",
			"Elf",
			"Quick and sharp-minded, but a little less sturdy.",
			{"dex": 2, "int": 1, "con": -1},
			-1,
			1,
			MvpConstants.SPRITE_PLAYER_ELF
		),
		"orc": _make_race(
			"orc",
			"Orc",
			"Strong and durable, with less patience for polite rooms.",
			{"str": 2, "con": 1, "cha": -1},
			2,
			0,
			MvpConstants.SPRITE_PLAYER_ORC
		),
		"dwarf": _make_race(
			"dwarf",
			"Dwarf",
			"Tough and grounded, built for long roads and bad ideas.",
			{"con": 2, "str": 1, "dex": -1},
			3,
			-1,
			MvpConstants.SPRITE_PLAYER_DWARF
		),
	}


func _make_race(race_id: String, race_name: String, description: String, stat_mods: Dictionary, max_hp_bonus: int, max_ap_bonus: int, sprite: String) -> Dictionary:
	var normalized_mods: Dictionary = {}
	for stat_key: String in BASE_STAT_KEYS:
		normalized_mods[stat_key] = int(stat_mods.get(stat_key, 0))
	return {
		"race_id": race_id,
		"name": race_name,
		"description": description,
		"stat_mods": normalized_mods,
		"max_hp_bonus": max_hp_bonus,
		"max_ap_bonus": max_ap_bonus,
		"sprite": sprite,
	}
