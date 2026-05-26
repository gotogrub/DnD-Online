extends Control
class_name DicePanel
## Sends quick public dice roll intents to the authoritative server.

const BUTTONS := {
	"D4Button": {"expr": "1d4", "label": "d4", "icon": "res://tileset/d4.png"},
	"D6Button": {"expr": "1d6", "label": "d6", "icon": "res://tileset/d6.png"},
	"D8Button": {"expr": "1d8", "label": "d8", "icon": "res://tileset/d8.png"},
	"D12Button": {"expr": "1d12", "label": "d12", "icon": "res://tileset/d12.png"},
	"D20Button": {"expr": "1d20", "label": "d20", "icon": "res://tileset/d20.png"},
}

const OPEN_Y := 0.0
const CLOSED_Y := 208.0
const TWEEN_SECONDS := 0.16

@onready var dice_buttons: PanelContainer = $DiceButtons
@onready var toggle_button: Button = $ToggleButton

var is_open := false
var slide_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_roll_buttons()
	_setup_toggle_button()
	_set_open(false, false)


func _setup_roll_buttons() -> void:
	for button_name in BUTTONS.keys():
		var button: Button = get_node_or_null("DiceButtons/VBoxContainer/%s" % str(button_name)) as Button
		if not button:
			continue
		var config: Dictionary = BUTTONS[button_name] as Dictionary
		var expr: String = str(config.get("expr", "1d20"))
		button.text = str(config.get("label", expr))
		button.tooltip_text = "Roll %s" % expr
		_apply_button_icon(button, str(config.get("icon", "")))
		button.pressed.connect(_on_roll_pressed.bind(expr))


func _setup_toggle_button() -> void:
	toggle_button.tooltip_text = "Show dice"
	_apply_button_icon(toggle_button, "res://tileset/d20.png")
	toggle_button.toggled.connect(_on_toggle_pressed)


func _apply_button_icon(button: Button, icon_path: String) -> void:
	if not ResourceLoader.exists(icon_path):
		return
	var icon: Texture2D = load(icon_path) as Texture2D
	if not icon:
		return
	button.icon = icon
	button.expand_icon = true
	button.text = ""


func _on_toggle_pressed(open: bool) -> void:
	_set_open(open, true)


func _set_open(open: bool, animate: bool) -> void:
	is_open = open
	toggle_button.set_pressed_no_signal(open)
	toggle_button.tooltip_text = "Hide dice" if open else "Show dice"
	if slide_tween and slide_tween.is_valid():
		slide_tween.kill()
	if open:
		dice_buttons.visible = true
	var target_y: float = OPEN_Y if open else CLOSED_Y
	var target_alpha: float = 1.0 if open else 0.0
	if not animate:
		dice_buttons.position.y = target_y
		dice_buttons.modulate.a = target_alpha
		dice_buttons.visible = open
		return
	slide_tween = create_tween()
	slide_tween.set_parallel(true)
	slide_tween.tween_property(dice_buttons, "position:y", target_y, TWEEN_SECONDS)
	slide_tween.tween_property(dice_buttons, "modulate:a", target_alpha, TWEEN_SECONDS)
	if not open:
		slide_tween.finished.connect(_hide_dice_buttons_if_closed)


func _hide_dice_buttons_if_closed() -> void:
	if is_open:
		return
	dice_buttons.visible = false


func _on_roll_pressed(expr: String) -> void:
	NetworkService.request_roll(expr)
