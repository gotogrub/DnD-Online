extends PanelContainer
class_name CreateCharacterPanel
## Creates a new server-side CharacterState; combat/class/inventory remain out of scope.

signal back_requested()

const RACE_ORDER: Array[String] = ["human", "elf", "orc", "dwarf"]

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var race_option: OptionButton = $VBoxContainer/RaceOption
@onready var race_description_label: Label = $VBoxContainer/RaceDescriptionLabel
@onready var race_mods_label: Label = $VBoxContainer/RaceModsLabel
@onready var stats_grid: GridContainer = $VBoxContainer/StatsGrid
@onready var points_left_label: Label = $VBoxContainer/PointsLeftLabel
@onready var max_hp_label: Label = $VBoxContainer/DerivedGrid/MaxHpValue
@onready var max_ap_label: Label = $VBoxContainer/DerivedGrid/MaxApValue
@onready var defense_label: Label = $VBoxContainer/DerivedGrid/DefenseValue
@onready var initiative_label: Label = $VBoxContainer/DerivedGrid/InitiativeValue
@onready var create_button: Button = $VBoxContainer/ButtonRow/CreateButton
@onready var cancel_button: Button = $VBoxContainer/ButtonRow/CancelButton

var selected_race_id: String = "human"
var base_stats: Dictionary = {}
var stat_value_labels: Dictionary = {}
var stat_minus_buttons: Dictionary = {}
var stat_plus_buttons: Dictionary = {}


func _ready() -> void:
	name_input.max_length = MvpConstants.MAX_NAME_LENGTH
	_populate_races()
	_build_stat_controls()
	race_option.item_selected.connect(_on_race_selected)
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	if not NetworkService.character_created.is_connected(_on_character_created):
		NetworkService.character_created.connect(_on_character_created)
	if not NetworkService.character_create_rejected.is_connected(_on_character_create_rejected):
		NetworkService.character_create_rejected.connect(_on_character_create_rejected)
	_reset_form()
	visible = false


func open_panel() -> void:
	_reset_form()
	visible = true
	name_input.grab_focus()


func _reset_form() -> void:
	base_stats = RaceRegistry.base_stats(MvpConstants.DEFAULT_BASE_STAT)
	selected_race_id = "human"
	name_input.text = ""
	create_button.disabled = false
	status_label.text = "Choose race and stats."
	_select_race_id(selected_race_id)
	_refresh_all()


func _populate_races() -> void:
	race_option.clear()
	for race_id: String in RACE_ORDER:
		var race: Dictionary = RaceRegistry.get_race(race_id)
		var index: int = race_option.get_item_count()
		race_option.add_item(str(race.get("name", race_id)))
		race_option.set_item_metadata(index, race_id)
	race_option.select(0)


func _build_stat_controls() -> void:
	for child: Node in stats_grid.get_children():
		child.queue_free()
	stat_value_labels.clear()
	stat_minus_buttons.clear()
	stat_plus_buttons.clear()
	for stat_key: String in RaceRegistry.BASE_STAT_KEYS:
		var name_label := Label.new()
		name_label.text = stat_key.to_upper()
		stats_grid.add_child(name_label)
		var minus_button := Button.new()
		minus_button.text = "-"
		minus_button.custom_minimum_size = Vector2(28, 0)
		minus_button.pressed.connect(_on_stat_step.bind(stat_key, -1))
		stats_grid.add_child(minus_button)
		var value_label := Label.new()
		value_label.text = str(MvpConstants.DEFAULT_BASE_STAT)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.custom_minimum_size = Vector2(42, 0)
		stats_grid.add_child(value_label)
		var plus_button := Button.new()
		plus_button.text = "+"
		plus_button.custom_minimum_size = Vector2(28, 0)
		plus_button.pressed.connect(_on_stat_step.bind(stat_key, 1))
		stats_grid.add_child(plus_button)
		stat_minus_buttons[stat_key] = minus_button
		stat_value_labels[stat_key] = value_label
		stat_plus_buttons[stat_key] = plus_button


func _on_race_selected(index: int) -> void:
	var metadata: Variant = race_option.get_item_metadata(index)
	selected_race_id = str(metadata)
	if selected_race_id.is_empty():
		selected_race_id = "human"
	_refresh_all()


func _on_stat_step(stat_key: String, delta: int) -> void:
	var current_value: int = int(base_stats.get(stat_key, MvpConstants.DEFAULT_BASE_STAT))
	var next_value: int = current_value + delta
	if next_value < MvpConstants.CHARACTER_STAT_MIN or next_value > MvpConstants.CHARACTER_STAT_MAX:
		return
	var next_stats: Dictionary = base_stats.duplicate(true)
	next_stats[stat_key] = next_value
	if _spent_points(next_stats) > MvpConstants.CHARACTER_POINT_BUY_POINTS:
		status_label.text = "No stat points left."
		return
	base_stats = next_stats
	status_label.text = "Choose race and stats."
	_refresh_all()


func _on_create_pressed() -> void:
	var payload: Dictionary = {
		"name": name_input.text.strip_edges(),
		"race_id": selected_race_id,
		"base_stats": base_stats.duplicate(true),
	}
	var validation: Dictionary = CharacterService.validate_character_create_payload(payload)
	if not bool(validation.get("ok", false)):
		status_label.text = str(validation.get("error", "invalid character"))
		return
	create_button.disabled = true
	status_label.text = "Creating character..."
	if not NetworkService.request_create_character(payload):
		create_button.disabled = false
		status_label.text = "Could not send create request."


func _on_cancel_pressed() -> void:
	visible = false
	back_requested.emit()


func _on_character_created(_payload: Dictionary) -> void:
	create_button.disabled = false
	status_label.text = "Character created."
	visible = false


func _on_character_create_rejected(payload: Dictionary) -> void:
	create_button.disabled = false
	status_label.text = str(payload.get("reason", "invalid character"))


func _refresh_all() -> void:
	_refresh_race_preview()
	_refresh_stat_controls()
	_refresh_derived_preview()


func _refresh_race_preview() -> void:
	var race: Dictionary = RaceRegistry.get_race(selected_race_id)
	race_description_label.text = str(race.get("description", ""))
	race_mods_label.text = _format_race_mods(race.get("stat_mods", {}) as Dictionary)


func _refresh_stat_controls() -> void:
	var points_left: int = MvpConstants.CHARACTER_POINT_BUY_POINTS - _spent_points(base_stats)
	points_left_label.text = "Points left: %d" % points_left
	for stat_key: String in RaceRegistry.BASE_STAT_KEYS:
		var stat_value: int = int(base_stats.get(stat_key, MvpConstants.DEFAULT_BASE_STAT))
		var value_label: Label = stat_value_labels.get(stat_key) as Label
		if value_label != null:
			value_label.text = str(stat_value)
		var minus_button: Button = stat_minus_buttons.get(stat_key) as Button
		if minus_button != null:
			minus_button.disabled = stat_value <= MvpConstants.CHARACTER_STAT_MIN
		var plus_button: Button = stat_plus_buttons.get(stat_key) as Button
		if plus_button != null:
			var next_stats: Dictionary = base_stats.duplicate(true)
			next_stats[stat_key] = stat_value + 1
			plus_button.disabled = stat_value >= MvpConstants.CHARACTER_STAT_MAX or _spent_points(next_stats) > MvpConstants.CHARACTER_POINT_BUY_POINTS


func _refresh_derived_preview() -> void:
	var derived_stats: Dictionary = CharacterService.derive_stats(base_stats, selected_race_id)
	max_hp_label.text = str(int(derived_stats.get("max_hp", 0)))
	max_ap_label.text = str(int(derived_stats.get("max_ap", 0)))
	defense_label.text = str(int(derived_stats.get("defense", 0)))
	initiative_label.text = str(int(derived_stats.get("initiative", 0)))


func _select_race_id(race_id: String) -> void:
	for index in range(race_option.get_item_count()):
		if str(race_option.get_item_metadata(index)) == race_id:
			race_option.select(index)
			return
	race_option.select(0)


func _spent_points(stats: Dictionary) -> int:
	var spent_points: int = 0
	for stat_key: String in RaceRegistry.BASE_STAT_KEYS:
		spent_points += int(stats.get(stat_key, MvpConstants.DEFAULT_BASE_STAT)) - MvpConstants.DEFAULT_BASE_STAT
	return spent_points


func _format_race_mods(stat_mods: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_key: String in RaceRegistry.BASE_STAT_KEYS:
		var modifier: int = int(stat_mods.get(stat_key, 0))
		if modifier == 0:
			continue
		var sign: String = "+" if modifier > 0 else ""
		parts.append("%s %s%d" % [stat_key.to_upper(), sign, modifier])
	if parts.is_empty():
		return "Race mods: none"
	return "Race mods: %s" % ", ".join(PackedStringArray(parts))
