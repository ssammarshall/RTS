class_name UnitCard extends Control

signal card_selected(card: UnitCard)

@export var button: UnitCardButton
@export var selected_highlight: TextureRect

var is_selected: bool = false:
	set(value):
		is_selected = value
		selected_highlight.visible = value

var index: int = -1
var unit: Unit

func _ready() -> void:
	button.pressed.connect(Callable(_on_button_pressed))

# Connects this UnitCard to a Unit.
func setup(num: int, unt: Unit) -> void:
	index = num
	unit = unt
	unit.selected.connect(Callable(_on_set_selected))
	
	button.icon = unit.portrait

func _on_button_pressed() -> void:
	card_selected.emit(self)

func _on_set_selected(value: bool) -> void:
	is_selected = value
