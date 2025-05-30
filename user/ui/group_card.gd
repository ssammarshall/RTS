class_name GroupCard extends Control

@export var label: Label
@export var h_box_container: HBoxContainer

signal card_selected(card: UnitCard)

var group: Group
var group_number: int = -1

var units: Array[Unit]
var unit_cards: Array[UnitCard]

# Connect this GroupCard to a Group.
func setup(grp: Group) -> void:
	group = grp
	group_number = group.group_number * 100
	if group_number < 1000 and group_number > 0: # Only selectable control_groups (1-9) have numbered labels.
		@warning_ignore("integer_division")
		var num: int = floor(group_number / 100)
		label.text = str(num)
	else: label.hide()
	
	var i: int = 0
	units = group.units
	for unit in units:
		var new_card := unit.create_unit_card(group_number + i)
		add_unit(new_card)
		new_card.card_selected.connect(_on_card_selected)
		i += 1

func _on_card_selected(new_card: UnitCard) -> void:
	card_selected.emit(new_card)

func add_unit(new_card: UnitCard) -> void:
	if new_card == null: return
	
	unit_cards.append(new_card)
	h_box_container.add_child(new_card)

func remove_unit(card: UnitCard) -> void:
	if not unit_cards.has(card): return
	
	var index: int = unit_cards.find(card)
	unit_cards.remove_at(index)
	
	h_box_container.remove_child(card) # might want to check for child first...
