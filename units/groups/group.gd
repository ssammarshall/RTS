class_name Group extends Node3D

# Identifier.
var group_number: int

# Units.
var units: Array[Unit]

enum FORMATION {
	BOX,
	SCATTER
}
var current_formation: FORMATION = FORMATION.BOX

# On group creation.
func _init(index: int) -> void:
	group_number = index

# Add Unit.
func add_unit(unit: Unit) -> void:
	if units.has(unit):return
	units.append(unit) # Add to Group.

# Append array of Units.
func add_units(array: Array[Unit]) -> void:
	for unit in array:
		add_unit(unit)

# Remove Unit.
func remove_unit(unit: Unit) -> void:
	var index:int = -1
	for x in size():
		if units[x] == unit:index = x
	if index == -1: return
	units.remove_at(index)

func get_unit_positions() -> Array[Vector3]:
	var array: Array[Vector3]
	for unit in units:
		array.append(unit.global_position)
	return array

# Deselect and clear all Units.
func empty_group() -> void:
	select(false)
	units.clear()

func size() -> int:
	return units.size()

func has(unit: Unit) -> bool:
	if units.has(unit): return true
	else: return false

# Select all Units in Group
func select(value: bool) -> void:
	for unit in units:
		unit.select(value)

# Create GroupCard to be used by GUI.
func create_group_card() -> GroupCard:
	var group_card := Global.GROUP_CARD.instantiate() as GroupCard
	group_card.setup(self)
	
	return group_card

# Add path to each Unit's PathFinder.
func add_path_pos(pos: Vector3) -> void:
	for unit in units:
		unit.path_finder.add_to_path_queue(pos)

func cancel_commands() -> void:
	for unit in units:
		unit.clear_commands()

# End all pathing for each Unit's PathFinder.
func clear_pathing() -> void:
	for unit in units:
		unit.path_finder.end_pathing()
