class_name WaitForCapacityCommand extends UnitCommand

func enter(unit: Unit) -> void:
	if unit.pathing: unit.path_finder.end_pathing()

func execute(_unit: Unit, _delta: float) -> void:
	pass # Idle.
