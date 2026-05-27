extends Node
class_name CharacterServiceSingleton
## Creates persistent CharacterState payloads and maps them to temporary map actors.


func create_default_character(owner_key: String, character_name: String, race_id: String = "human") -> Dictionary:
	return create_character(owner_key, character_name, race_id, RaceRegistry.base_stats())


func create_character(owner_key: String, character_name: String, race_id: String, base_stats: Dictionary) -> Dictionary:
	var normalized_owner_key: String = normalize_owner_key(owner_key)
	var normalized_race_id: String = RaceRegistry.normalize_race_id(race_id)
	var normalized_name: String = normalize_character_name(character_name)
	var normalized_base_stats: Dictionary = RaceRegistry.normalize_base_stats(base_stats)
	var derived_stats: Dictionary = derive_stats(normalized_base_stats, normalized_race_id)
	var now: int = int(Time.get_unix_time_from_system())
	var race: Dictionary = RaceRegistry.get_race(normalized_race_id)
	var character: Dictionary = {
		"character_id": generate_character_id(normalized_owner_key),
		"owner_key": normalized_owner_key,
		"name": normalized_name,
		"race_id": normalized_race_id,
		"base_stats": normalized_base_stats,
		"derived_stats": derived_stats,
		"current": {
			"hp": int(derived_stats.get("max_hp", 1)),
			"ap": int(derived_stats.get("max_ap", 1)),
		},
		"sprite": str(race.get("sprite", MvpConstants.DEFAULT_PLAYER_SPRITE)),
		"last_tile": Vector2i(-2, 7),
		"created_at": now,
		"last_used_at": now,
	}
	save_character(character)
	_add_character_to_owner_index(normalized_owner_key, str(character.get("character_id", "")))
	return character.duplicate(true)


func get_or_create_character_for_owner(owner_key: String, character_name: String, race_id: String = "human") -> Dictionary:
	var normalized_owner_key: String = normalize_owner_key(owner_key)
	var characters: Array[Dictionary] = load_characters_for_owner(normalized_owner_key)
	if not characters.is_empty():
		var character: Dictionary = _select_last_used_character(characters)
		character["last_used_at"] = int(Time.get_unix_time_from_system())
		save_character(character)
		return character.duplicate(true)
	return create_default_character(normalized_owner_key, character_name, race_id)


func derive_stats(base_stats: Dictionary, race_id: String) -> Dictionary:
	var race: Dictionary = RaceRegistry.get_race(race_id)
	var stat_mods: Dictionary = race.get("stat_mods", {}) as Dictionary
	var dex: int = _effective_stat(base_stats, stat_mods, "dex")
	var con: int = _effective_stat(base_stats, stat_mods, "con")
	return {
		"max_hp": max(1, 10 + con * 2 + int(race.get("max_hp_bonus", 0))),
		"max_ap": max(1, 6 + int(floor(float(dex) / 2.0)) + int(race.get("max_ap_bonus", 0))),
		"defense": 10 + dex,
		"initiative": dex,
	}


func character_to_actor(character: Dictionary, peer_id: int, tile: Vector2i) -> Dictionary:
	var character_id: String = str(character.get("character_id", ""))
	var derived_stats: Dictionary = character.get("derived_stats", {}) as Dictionary
	var current: Dictionary = character.get("current", {}) as Dictionary
	var max_ap: int = int(derived_stats.get("max_ap", MvpConstants.DEFAULT_MAX_AP))
	var actor: Dictionary = EntityData.make_actor(
		"actor_peer_%d" % peer_id,
		MvpConstants.ACTOR_KIND_PLAYER,
		peer_id,
		str(character.get("name", "Player")),
		tile,
		str(character.get("sprite", MvpConstants.DEFAULT_PLAYER_SPRITE)),
		max_ap,
		true,
		character_id
	)
	actor[EntityData.AP] = int(current.get("ap", max_ap))
	return actor


func normalize_character_name(character_name: String) -> String:
	var normalized_name: String = character_name.strip_edges()
	if normalized_name.is_empty():
		normalized_name = "Player"
	return normalized_name.substr(0, MvpConstants.MAX_NAME_LENGTH)


func normalize_owner_key(owner_key: String) -> String:
	var normalized_owner_key: String = owner_key.strip_edges()
	if normalized_owner_key.is_empty():
		normalized_owner_key = "unknown"
	return normalized_owner_key


func generate_character_id(owner_key: String) -> String:
	var safe_owner_key: String = _safe_file_id(owner_key)
	var now_msec: int = Time.get_ticks_msec()
	var random_part: int = randi() % 1000000
	return "character_%s_%d_%06d" % [safe_owner_key, now_msec, random_part]


func load_characters_for_owner(owner_key: String) -> Array[Dictionary]:
	var character_ids: Array[String] = load_owner_index(owner_key)
	var characters: Array[Dictionary] = []
	for character_id: String in character_ids:
		var character: Dictionary = load_character(character_id)
		if not character.is_empty():
			characters.append(character)
	return characters


func save_character(character: Dictionary) -> void:
	var character_id: String = str(character.get("character_id", ""))
	if character_id.is_empty():
		return
	_ensure_storage_dirs()
	var file: FileAccess = FileAccess.open(_character_path(character_id), FileAccess.WRITE)
	if file == null:
		push_warning("Could not save character: %s" % character_id)
		return
	file.store_string(JSON.stringify(_serialize_character(character), "\t"))


func load_character(character_id: String) -> Dictionary:
	var safe_character_id: String = _safe_file_id(character_id)
	var path: String = _character_path(safe_character_id)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed_data: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed_data is Dictionary):
		return {}
	return _deserialize_character(parsed_data as Dictionary)


func save_owner_index(owner_key: String, character_ids: Array[String]) -> void:
	var normalized_owner_key: String = normalize_owner_key(owner_key)
	_ensure_storage_dirs()
	var clean_ids: Array[String] = []
	for character_id: String in character_ids:
		if character_id.is_empty() or clean_ids.has(character_id):
			continue
		clean_ids.append(character_id)
	var index_payload: Dictionary = {
		"owner_key": normalized_owner_key,
		"character_ids": clean_ids,
		"last_character_id": clean_ids[clean_ids.size() - 1] if not clean_ids.is_empty() else "",
	}
	var file: FileAccess = FileAccess.open(_owner_index_path(normalized_owner_key), FileAccess.WRITE)
	if file == null:
		push_warning("Could not save owner index: %s" % normalized_owner_key)
		return
	file.store_string(JSON.stringify(index_payload, "\t"))


func load_owner_index(owner_key: String) -> Array[String]:
	var normalized_owner_key: String = normalize_owner_key(owner_key)
	var path: String = _owner_index_path(normalized_owner_key)
	var character_ids: Array[String] = []
	if not FileAccess.file_exists(path):
		return character_ids
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return character_ids
	var parsed_data: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed_data is Dictionary):
		return character_ids
	var raw_ids: Variant = (parsed_data as Dictionary).get("character_ids", [])
	if raw_ids is Array:
		for raw_id: Variant in raw_ids:
			var character_id: String = str(raw_id).strip_edges()
			if character_id.is_empty() or character_ids.has(character_id):
				continue
			character_ids.append(character_id)
	return character_ids


func _ready() -> void:
	randomize()
	_ensure_storage_dirs()


func _effective_stat(base_stats: Dictionary, stat_mods: Dictionary, stat_key: String) -> int:
	return int(base_stats.get(stat_key, 1)) + int(stat_mods.get(stat_key, 0))


func _select_last_used_character(characters: Array[Dictionary]) -> Dictionary:
	var selected: Dictionary = characters[0]
	var selected_last_used: int = int(selected.get("last_used_at", 0))
	for character: Dictionary in characters:
		var last_used: int = int(character.get("last_used_at", 0))
		if last_used > selected_last_used:
			selected = character
			selected_last_used = last_used
	return selected


func _add_character_to_owner_index(owner_key: String, character_id: String) -> void:
	if character_id.is_empty():
		return
	var character_ids: Array[String] = load_owner_index(owner_key)
	if not character_ids.has(character_id):
		character_ids.append(character_id)
	save_owner_index(owner_key, character_ids)


func _ensure_storage_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(MvpConstants.SERVER_CHARACTERS_DIR)
	DirAccess.make_dir_recursive_absolute(MvpConstants.SERVER_OWNERS_DIR)


func _character_path(character_id: String) -> String:
	return "%s/%s.json" % [MvpConstants.SERVER_CHARACTERS_DIR, _safe_file_id(character_id)]


func _owner_index_path(owner_key: String) -> String:
	return "%s/%s.json" % [MvpConstants.SERVER_OWNERS_DIR, _safe_file_id(owner_key)]


func _safe_file_id(value: String) -> String:
	var safe_value: String = value.strip_edges()
	safe_value = safe_value.replace("/", "_")
	safe_value = safe_value.replace("\\", "_")
	safe_value = safe_value.replace(":", "_")
	safe_value = safe_value.replace("..", "_")
	safe_value = safe_value.replace(" ", "_")
	if safe_value.is_empty():
		safe_value = "unknown"
	return safe_value


func _serialize_character(character: Dictionary) -> Dictionary:
	var payload: Dictionary = character.duplicate(true)
	payload["last_tile"] = _serialize_vector2i(_as_vector2i(payload.get("last_tile", Vector2i.ZERO)))
	return payload


func _deserialize_character(payload: Dictionary) -> Dictionary:
	var character: Dictionary = payload.duplicate(true)
	character["owner_key"] = normalize_owner_key(str(character.get("owner_key", "")))
	character["name"] = normalize_character_name(str(character.get("name", "Player")))
	character["race_id"] = RaceRegistry.normalize_race_id(str(character.get("race_id", "human")))
	character["base_stats"] = RaceRegistry.normalize_base_stats(character.get("base_stats", {}) as Dictionary)
	character["derived_stats"] = derive_stats(character.get("base_stats", {}) as Dictionary, str(character.get("race_id", "human")))
	character["current"] = _normalize_current(character.get("current", {}) as Dictionary, character.get("derived_stats", {}) as Dictionary)
	character["last_tile"] = _as_vector2i(character.get("last_tile", Vector2i(-2, 7)))
	if str(character.get("sprite", "")).is_empty():
		var race: Dictionary = RaceRegistry.get_race(str(character.get("race_id", "human")))
		character["sprite"] = str(race.get("sprite", MvpConstants.DEFAULT_PLAYER_SPRITE))
	return character


func _normalize_current(current: Dictionary, derived_stats: Dictionary) -> Dictionary:
	var max_hp: int = int(derived_stats.get("max_hp", 1))
	var max_ap: int = int(derived_stats.get("max_ap", MvpConstants.DEFAULT_MAX_AP))
	return {
		"hp": clampi(int(current.get("hp", max_hp)), 0, max_hp),
		"ap": clampi(int(current.get("ap", max_ap)), 0, max_ap),
	}


func _serialize_vector2i(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}


func _as_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
