extends PanelContainer
class_name CharacterSheetPanel
## Displays the local persistent CharacterState; editing/creation is intentionally out of scope.

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var race_label: Label = $VBoxContainer/RaceLabel
@onready var str_label: Label = $VBoxContainer/StatsGrid/StrValue
@onready var dex_label: Label = $VBoxContainer/StatsGrid/DexValue
@onready var con_label: Label = $VBoxContainer/StatsGrid/ConValue
@onready var int_label: Label = $VBoxContainer/StatsGrid/IntValue
@onready var wis_label: Label = $VBoxContainer/StatsGrid/WisValue
@onready var cha_label: Label = $VBoxContainer/StatsGrid/ChaValue
@onready var hp_label: Label = $VBoxContainer/DerivedGrid/HpValue
@onready var ap_label: Label = $VBoxContainer/DerivedGrid/ApValue
@onready var defense_label: Label = $VBoxContainer/DerivedGrid/DefenseValue
@onready var initiative_label: Label = $VBoxContainer/DerivedGrid/InitiativeValue
@onready var character_id_label: Label = $VBoxContainer/CharacterIdLabel


func _ready() -> void:
	if not SessionState.local_character_changed.is_connected(_on_local_character_changed):
		SessionState.local_character_changed.connect(_on_local_character_changed)
	refresh()


func refresh() -> void:
	_apply_character(SessionState.get_local_character())


func _on_local_character_changed(character: Dictionary) -> void:
	_apply_character(character)


func _apply_character(character: Dictionary) -> void:
	if character.is_empty():
		title_label.text = "Character"
		name_label.text = "No character selected"
		race_label.text = "Race: -"
		_set_base_stat_labels({})
		_set_derived_labels({}, {})
		character_id_label.text = "ID: -"
		return
	var race_id: String = str(character.get("race_id", "human"))
	var race: Dictionary = RaceRegistry.get_race(race_id)
	var race_name: String = str(race.get("name", race_id))
	var base_stats: Dictionary = _dictionary_from_variant(character.get("base_stats", {}))
	var derived_stats: Dictionary = _dictionary_from_variant(character.get("derived_stats", {}))
	var current: Dictionary = _dictionary_from_variant(character.get("current", {}))
	title_label.text = "Character"
	name_label.text = "Name: %s" % str(character.get("name", "Player"))
	race_label.text = "Race: %s" % race_name
	_set_base_stat_labels(base_stats)
	_set_derived_labels(current, derived_stats)
	character_id_label.text = "ID: %s" % str(character.get("character_id", "-"))


func _set_base_stat_labels(base_stats: Dictionary) -> void:
	str_label.text = str(int(base_stats.get("str", 0)))
	dex_label.text = str(int(base_stats.get("dex", 0)))
	con_label.text = str(int(base_stats.get("con", 0)))
	int_label.text = str(int(base_stats.get("int", 0)))
	wis_label.text = str(int(base_stats.get("wis", 0)))
	cha_label.text = str(int(base_stats.get("cha", 0)))


func _set_derived_labels(current: Dictionary, derived_stats: Dictionary) -> void:
	var max_hp: int = int(derived_stats.get("max_hp", 0))
	var max_ap: int = int(derived_stats.get("max_ap", 0))
	hp_label.text = "%d / %d" % [int(current.get("hp", max_hp)), max_hp]
	ap_label.text = "%d / %d" % [int(current.get("ap", max_ap)), max_ap]
	defense_label.text = str(int(derived_stats.get("defense", 0)))
	initiative_label.text = str(int(derived_stats.get("initiative", 0)))


func _dictionary_from_variant(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
