class_name InteractCommand extends UnitCommand

var target: Node3D

func _init(_target: Node3D) -> void:
	target = _target
	assert(target != null)

# Called once UnitCommand is set to active command.
func enter(unit: Unit) -> void:
	if not unit.nearby_bodies.has(target): unit.path_finder.add_to_path_queue(target.global_position)
	else: interact(unit)

# Called upon to perform specific action.
func execute(unit: Unit, _delta: float) -> void:
	if not unit.nearby_bodies.has(target): return
	
	interact(unit)

# Called once UnitCommand is finished or changed.
func exit(unit: Unit) -> void:
	if unit.pathing: unit.path_finder.end_pathing()

func interact(unit: Unit) -> void:
	if target is ResourceSpawn:
		var rs := target as ResourceSpawn
		unit.inventory.swap_resource_type(rs.resource.type)
		if unit.inventory.resource.amount >= unit.inventory.resource_limit:
			print("Max capacity reached")
		else:
			rs.unit_interaction(unit)
	
	elif target is Building:
		var b := target as Building
		if not b.construction_complete:
			b.start_construction()
		else:
			b.unit_interaction(unit)
	
	finished.emit()
