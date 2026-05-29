extends PanelContainer
class_name InventoryPanel
## Displays the local character inventory; all mutations remain server-authoritative.

@onready var rows_container: VBoxContainer = $VBoxContainer/Content/LeftPane/ItemsScroll/RowsContainer
@onready var empty_label: Label = $VBoxContainer/Content/LeftPane/EmptyLabel
@onready var details_label: Label = $VBoxContainer/Content/DetailsPane/DetailsLabel
@onready var total_weight_label: Label = $VBoxContainer/BottomBar/TotalWeightLabel
@onready var use_button: Button = $VBoxContainer/ActionsBar/UseButton
@onready var equip_button: Button = $VBoxContainer/ActionsBar/EquipButton
@onready var use_on_button: Button = $VBoxContainer/ActionsBar/UseOnButton
@onready var drop_button: Button = $VBoxContainer/ActionsBar/DropButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var selected_item_uid := ""


func _ready() -> void:
	if not SessionState.local_inventory_changed.is_connected(_on_local_inventory_changed):
		SessionState.local_inventory_changed.connect(_on_local_inventory_changed)
	use_button.pressed.connect(_on_action_pressed.bind("Use is not implemented yet."))
	equip_button.pressed.connect(_on_action_pressed.bind("Equip is not implemented yet."))
	use_on_button.pressed.connect(_on_action_pressed.bind("Use On is not implemented yet."))
	drop_button.pressed.connect(_on_drop_pressed)
	if not NetworkService.system_message_received.is_connected(_on_system_message_received):
		NetworkService.system_message_received.connect(_on_system_message_received)
	refresh()


func refresh() -> void:
	_rebuild_rows()
	_update_details()
	_update_total_weight()


func _on_local_inventory_changed(_inventory: Dictionary) -> void:
	refresh()


func _rebuild_rows() -> void:
	for child: Node in rows_container.get_children():
		child.queue_free()
	var items: Array = _inventory_items()
	empty_label.visible = items.is_empty()
	if items.is_empty():
		selected_item_uid = ""
		return
	if selected_item_uid.is_empty() or _find_item_by_uid(selected_item_uid).is_empty():
		selected_item_uid = str((items[0] as Dictionary).get("item_uid", ""))
	for raw_item in items:
		var item: Dictionary = raw_item as Dictionary
		var item_uid: String = str(item.get("item_uid", ""))
		var item_id: String = str(item.get("item_id", ""))
		var quantity: int = int(item.get("quantity", 1))
		var row_button := Button.new()
		row_button.text = "%s x%d" % [_item_display_name(item), quantity]
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.toggle_mode = true
		row_button.button_pressed = item_uid == selected_item_uid
		row_button.pressed.connect(_on_item_row_pressed.bind(item_uid))
		row_button.tooltip_text = item_id
		rows_container.add_child(row_button)


func _on_item_row_pressed(item_uid: String) -> void:
	selected_item_uid = item_uid
	status_label.text = ""
	refresh()


func _update_details() -> void:
	var item: Dictionary = _find_item_by_uid(selected_item_uid)
	if item.is_empty():
		details_label.text = "No items"
		_set_action_buttons([])
		return
	var item_id: String = str(item.get("item_id", ""))
	var template: Dictionary = ItemRegistry.get_item(item_id)
	var quantity: int = int(item.get("quantity", 1))
	var base_value: int = int(template.get("base_value", 0))
	var weight: float = float(template.get("weight", 0.0))
	var actions: Array[String] = ItemRegistry.get_item_actions(item_id)
	var action_labels := PackedStringArray()
	for action: String in actions:
		action_labels.append(action)
	var details_lines := PackedStringArray([
		_item_display_name(item),
		"Type: %s" % str(template.get("type", "-")),
		"Category: %s" % str(template.get("category", "-")),
		"Quantity: %d" % quantity,
		"Base value: %d" % base_value,
		"Total value: %d" % (base_value * quantity),
		"Weight: %.2f" % weight,
		"Total weight: %.2f" % (weight * float(quantity)),
		"Stackable: %s" % ("yes" if bool(template.get("stackable", false)) else "no"),
		"Actions: %s" % ", ".join(action_labels),
		"",
		_item_description(item, template),
	])
	details_label.text = "\n".join(details_lines)
	_set_action_buttons(actions)


func _update_total_weight() -> void:
	var total_weight := 0.0
	for raw_item in _inventory_items():
		var item: Dictionary = raw_item as Dictionary
		total_weight += ItemRegistry.get_item_weight(str(item.get("item_id", ""))) * float(item.get("quantity", 1))
	total_weight_label.text = "Total weight: %.2f" % total_weight


func _set_action_buttons(actions: Array[String]) -> void:
	use_button.disabled = not actions.has("use")
	equip_button.disabled = not actions.has("equip")
	use_on_button.disabled = not actions.has("use_on")
	drop_button.disabled = not actions.has("drop")


func _on_action_pressed(message: String) -> void:
	status_label.text = message


func _on_drop_pressed() -> void:
	var item: Dictionary = _find_item_by_uid(selected_item_uid)
	if item.is_empty():
		status_label.text = "Select item first."
		return
	var quantity: int = int(item.get("quantity", 1))
	if not NetworkService.request_drop_inventory_item(selected_item_uid, quantity):
		status_label.text = "Could not send drop request."
		return
	status_label.text = "Drop request sent."


func _on_system_message_received(payload: Dictionary) -> void:
	var message: String = str(payload.get("message", ""))
	if message.begins_with("Dropped") or message.begins_with("Drop rejected"):
		status_label.text = message


func _inventory_items() -> Array:
	var inventory: Dictionary = SessionState.get_local_inventory()
	var raw_items: Variant = inventory.get("items", [])
	if raw_items is Array:
		return (raw_items as Array).duplicate(true)
	return []


func _find_item_by_uid(item_uid: String) -> Dictionary:
	if item_uid.is_empty():
		return {}
	for raw_item in _inventory_items():
		var item: Dictionary = raw_item as Dictionary
		if str(item.get("item_uid", "")) == item_uid:
			return item.duplicate(true)
	return {}


func _item_display_name(item: Dictionary) -> String:
	var custom_name: String = str(item.get("custom_name", "")).strip_edges()
	if not custom_name.is_empty():
		return custom_name
	return ItemRegistry.get_item_display_name(str(item.get("item_id", "")))


func _item_description(item: Dictionary, template: Dictionary) -> String:
	var custom_description: String = str(item.get("custom_description", "")).strip_edges()
	if not custom_description.is_empty():
		return custom_description
	return str(template.get("description", ""))
