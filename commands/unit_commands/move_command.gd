class_name MoveCommand extends UnitCommand

var target_position: Vector3

func _init(_target_position: Vector3 = Vector3.ZERO) -> void:
	target_position = _target_position

# Called once UnitCommand is set to active command.
func enter(unit: Unit) -> void:
	unit.path_finder.add_to_path_queue(target_position)

# Called upon to perform specific action.
func execute(unit: Unit, _delta: float) -> void:
	if not unit.pathing or target_position == Vector3.ZERO: finished.emit()

# Called once UnitCommand is finished or changed.
func exit(_unit: Unit) -> void:
	pass
