class_name ThirdPersonHUD extends CanvasLayer
# Shown while the player controls a unit.

@export var prompt: Label
@export var job: Label

func set_prompt(text: String) -> void:
	_show(prompt, text)

func set_job(text: String) -> void:
	_show(job, text)

func _show(label: Label, text: String) -> void:
	if label.text == text: return
	label.text = text
	label.visible = not text.is_empty()
