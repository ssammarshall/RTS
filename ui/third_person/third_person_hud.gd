class_name ThirdPersonHUD extends CanvasLayer
# Shown while the player controls a unit.

@export var prompt: Label

func set_prompt(text: String) -> void:
	if prompt.text == text: return
	prompt.text = text
	prompt.visible = not text.is_empty()
