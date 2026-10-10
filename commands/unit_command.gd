class_name UnitCommand extends Resource

signal finished

# Called once UnitCommand is set to active command.
func enter(_unit: Unit) -> void:
	pass

# Called on the Unit's scheduled think.
func think(_unit: Unit, _delta: float) -> void:
	pass

# Seconds until this command needs to think again. INF: only when the Unit is woken.
func next_think(_unit: Unit) -> float:
	return INF

# Called once UnitCommand is finished or changed.
func exit(_unit: Unit) -> void:
	pass

# Called when a Dormant Unit is promoted, before it jumps to where it would be by now.
func unpark(_unit: Unit) -> void:
	pass
