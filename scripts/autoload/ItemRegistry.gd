extends Node
class_name ItemRegistrySingleton
## Stores static MVP item templates; campaign loot state lives in SessionState.

const ITEM_ORDER: Array[String] = [
	"gold_coins",
	"coin_pouch",
	"small_gem",
	"jewelry",
	"minor_artifact",
	"healing_potion",
	"greater_healing_potion",
	"component_pouch",
]

var items: Dictionary = {}


func _ready() -> void:
	_register_default_items()


func get_item(item_id: String) -> Dictionary:
	var normalized_item_id: String = _normalize_item_id(item_id)
	var item: Dictionary = items.get(normalized_item_id, {}) as Dictionary
	return item.duplicate(true)


func has_item(item_id: String) -> bool:
	return items.has(_normalize_item_id(item_id))


func get_all_items() -> Array:
	var result: Array = []
	for item_id: String in ITEM_ORDER:
		if items.has(item_id):
			result.append((items[item_id] as Dictionary).duplicate(true))
	for raw_item_id in items.keys():
		var item_id: String = str(raw_item_id)
		if ITEM_ORDER.has(item_id):
			continue
		result.append((items[item_id] as Dictionary).duplicate(true))
	return result


func get_item_display_name(item_id: String) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return item_id
	return str(item.get("name", item_id))


func get_item_value(item_id: String) -> int:
	var item: Dictionary = get_item(item_id)
	return int(item.get("base_value", 0))


func get_item_weight(item_id: String) -> float:
	var item: Dictionary = get_item(item_id)
	return float(item.get("weight", 0.0))


func get_item_actions(item_id: String) -> Array[String]:
	var item: Dictionary = get_item(item_id)
	var result: Array[String] = []
	var raw_actions: Variant = item.get("actions", [])
	if raw_actions is Array:
		for raw_action: Variant in raw_actions:
			var action: String = str(raw_action).strip_edges().to_lower()
			if action.is_empty() or result.has(action):
				continue
			result.append(action)
	return result


func _register_default_items() -> void:
	var icon_path: String = _default_icon_path()
	items = {
		"gold_coins": _make_item(
			"gold_coins",
			"Gold Coins",
			"currency",
			"currency",
			true,
			1,
			0.01,
			"A handful of gold coins.",
			icon_path,
			["drop", "pickup"]
		),
		"coin_pouch": _make_item(
			"coin_pouch",
			"Coin Pouch",
			"currency",
			"currency",
			true,
			25,
			0.2,
			"A small pouch filled with coins.",
			icon_path,
			["drop", "pickup"]
		),
		"small_gem": _make_item(
			"small_gem",
			"Small Gem",
			"valuable",
			"gem",
			true,
			50,
			0.05,
			"A small gemstone that can be sold for a good price.",
			icon_path,
			["drop", "pickup"]
		),
		"jewelry": _make_item(
			"jewelry",
			"Jewelry",
			"valuable",
			"valuable",
			true,
			100,
			0.1,
			"Decorative jewelry with trade value.",
			icon_path,
			["drop", "pickup"]
		),
		"minor_artifact": _make_item(
			"minor_artifact",
			"Minor Artifact",
			"artifact",
			"artifact",
			false,
			250,
			1.0,
			"A strange minor artifact. Its purpose is unclear.",
			icon_path,
			["use_on", "drop", "pickup"]
		),
		"healing_potion": _make_item(
			"healing_potion",
			"Potion of Healing",
			"consumable",
			"potion",
			true,
			50,
			0.5,
			"A red potion that restores health. Use mechanics will be added later.",
			icon_path,
			["use", "drop", "pickup"]
		),
		"greater_healing_potion": _make_item(
			"greater_healing_potion",
			"Greater Potion of Healing",
			"consumable",
			"potion",
			true,
			150,
			0.5,
			"A stronger healing potion. Use mechanics will be added later.",
			icon_path,
			["use", "drop", "pickup"]
		),
		"component_pouch": _make_item(
			"component_pouch",
			"Spell Component Pouch",
			"component",
			"component",
			true,
			25,
			1.0,
			"A pouch of common spell components.",
			icon_path,
			["drop", "pickup"]
		),
	}


func _make_item(item_id: String, item_name: String, item_type: String, category: String, stackable: bool, base_value: int, weight: float, description: String, icon: String, actions: Array) -> Dictionary:
	return {
		"item_id": item_id,
		"name": item_name,
		"type": item_type,
		"category": category,
		"stackable": stackable,
		"base_value": base_value,
		"weight": weight,
		"description": description,
		"icon": icon,
		"actions": actions.duplicate(true),
	}


func _default_icon_path() -> String:
	if ResourceLoader.exists(MvpConstants.DEFAULT_ITEM_ICON):
		return MvpConstants.DEFAULT_ITEM_ICON
	if ResourceLoader.exists(MvpConstants.FALLBACK_ITEM_ICON):
		return MvpConstants.FALLBACK_ITEM_ICON
	return ""


func _normalize_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower()
