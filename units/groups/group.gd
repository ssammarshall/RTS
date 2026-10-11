class_name Group extends Node3D

# Identifier.
var group_number: int

# Units.
var units: Array[Unit]
var _index := {}

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
	if _index.has(unit): return
	_index[unit] = units.size()
	units.append(unit)

# Append array of Units.
func add_units(array: Array[Unit]) -> void:
	for unit in array:
		add_unit(unit)

# Remove Unit. The last unit takes its place.
func remove_unit(unit: Unit) -> void:
	var index: int = _index.get(unit, -1)
	if index < 0: return
	var last: Unit = units[units.size() - 1]
	units[index] = last
	_index[last] = index
	units.pop_back()
	_index.erase(unit)

func get_unit_positions() -> Array[Vector3]:
	var array: Array[Vector3]
	for unit in units:
		array.append(unit.global_position)
	return array

# Deselect and clear all Units.
func empty_group() -> void:
	select(false)
	units.clear()
	_index.clear()

func size() -> int:
	return units.size()

func has(unit: Unit) -> bool:
	return _index.has(unit)

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
