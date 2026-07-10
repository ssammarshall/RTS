class_name Job extends Resource

# Available Commands.
var schedule: Array[UnitCommand] = []
var current_command_index: int = 0

func start_schedule(_unit: Unit) -> void:
	current_command_index = 0

func get_current_command() -> UnitCommand:
	return schedule[current_command_index]

func next_command() -> UnitCommand:
	current_command_index += 1
	if current_command_index >= schedule.size(): current_command_index = 0
	
	return schedule[current_command_index]

func copy() -> Job:
	var job := Job.new()
	return job

func _update(_unit: Unit, _delta: float) -> void:
	pass
