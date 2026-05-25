extends PanelContainer
class_name RollToast
## Displays a single dice roll result.

@onready var result_label: Label = $ResultLabel


func show_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		result_label.text = str(result.get("error", "Roll error"))
		return
	result_label.text = "%s = %s" % [result.get("expression", ""), result.get("total", "")]
