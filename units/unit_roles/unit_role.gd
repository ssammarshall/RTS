class_name UnitRole extends Node

# Available Commands.
var schedule: Array[UnitCommand] = []
var current_command_index: int = 0

func start_schedule() -> void:
	current_command_index = 0

func get_current_command() -> UnitCommand:
	return schedule[current_command_index]

func next_command() -> UnitCommand:
	current_command_index += 1
	if current_command_index >= schedule.size(): current_command_index = 0
	
	return schedule[current_command_index]

func _ready() -> void:
	pass

func _update(_unit: Unit, _delta: float) -> void:
	pass
