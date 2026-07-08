class_name UnitCommand extends Resource

signal finished

# Called once UnitCommand is set to active command.
func enter(_unit: Unit) -> void:
	pass

# Called upon to perform specific action.
func execute(_unit: Unit, _delta: float) -> void:
	pass

# Called once UnitCommand is finished or changed.
func exit(_unit: Unit) -> void:
	pass
