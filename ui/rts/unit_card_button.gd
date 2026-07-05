class_name UnitCardButton extends Button

func _ready() -> void:
	action_mode = ActionMode.ACTION_MODE_BUTTON_PRESS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed("LMB"):
			get_viewport().set_input_as_handled()
			pressed.emit()
