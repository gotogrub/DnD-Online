extends PanelContainer
class_name DicePanel
## Sends quick public dice roll intents to the authoritative server.

const BUTTONS := {
	"D4Button": {"expr": "1d4", "label": "d4", "icon": "res://tileset/d4.png"},
	"D6Button": {"expr": "1d6", "label": "d6", "icon": "res://tileset/d6.png"},
	"D8Button": {"expr": "1d8", "label": "d8", "icon": "res://tileset/d8.png"},
	"D12Button": {"expr": "1d12", "label": "d12", "icon": "res://tileset/d12.png"},
	"D20Button": {"expr": "1d20", "label": "d20", "icon": "res://tileset/d20.png"},
}


func _ready() -> void:
	for button_name in BUTTONS.keys():
		var button: Button = get_node_or_null("HBoxContainer/%s" % str(button_name)) as Button
		if not button:
			continue
		var config: Dictionary = BUTTONS[button_name] as Dictionary
		var expr: String = str(config.get("expr", "1d20"))
		button.text = str(config.get("label", expr))
		button.tooltip_text = "Roll %s" % expr
		var icon_path: String = str(config.get("icon", ""))
		if ResourceLoader.exists(icon_path):
			var icon: Texture2D = load(icon_path) as Texture2D
			if icon:
				button.icon = icon
				button.expand_icon = true
				button.text = ""
		button.pressed.connect(_on_roll_pressed.bind(expr))


func _on_roll_pressed(expr: String) -> void:
	NetworkService.request_roll(expr)
