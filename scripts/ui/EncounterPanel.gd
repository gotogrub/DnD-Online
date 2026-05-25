extends PanelContainer
class_name EncounterPanel
## Shows current encounter turn state and emits a next-turn intent.

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var ap_label: Label = $VBoxContainer/ApLabel
@onready var next_turn_button: Button = $VBoxContainer/NextTurnButton


func _ready() -> void:
	next_turn_button.pressed.connect(_on_next_turn_pressed)


func apply_encounter_state(state: Dictionary) -> void:
	round_label.text = "Round: %s" % state.get("round", "-")
	turn_label.text = "Turn: %s" % state.get("current_actor_id", "-")
	ap_label.text = "AP: -"


func _on_next_turn_pressed() -> void:
	NetworkService.send_intent(NetMessages.C2S_ENCOUNTER_COMMAND, {
		"command": "turn",
		"args": ["next"],
	})
