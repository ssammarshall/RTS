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

# Called when a node enters the Unit's interaction area.
func on_nearby_entered(_unit: Unit, _node: Node3D) -> void:
	pass

# Called once UnitCommand is finished or changed.
func exit(_unit: Unit) -> void:
	pass
