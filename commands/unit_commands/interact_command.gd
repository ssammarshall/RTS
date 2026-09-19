class_name InteractCommand extends UnitCommand

const INTERACT_INTERVAL := 1.0 / 60.0

var target: Node3D
var _elapsed: float = 0.0

func _init(_target: Node3D) -> void:
	target = _target
	assert(target != null)

# Called once UnitCommand is set to active command.
func enter(unit: Unit) -> void:
	_elapsed = 0.0
	if not unit.nearby_bodies.has(target): unit.path_finder.add_to_path_queue(target.global_position)
	else: interact(unit)

# Called upon to perform specific action.
func execute(unit: Unit, delta: float) -> void:
	if not unit.nearby_bodies.has(target): return
	
	_elapsed += delta
	while _elapsed >= INTERACT_INTERVAL and unit.command == self:
		_elapsed -= INTERACT_INTERVAL
		interact(unit)

# Called once UnitCommand is finished or changed.
func exit(unit: Unit) -> void:
	if unit.pathing: unit.path_finder.end_pathing()

func interact(unit: Unit) -> void:
	if target is ResourceSpawn:
		var rs := target as ResourceSpawn
		if rs.get_item_type() == ItemData.Type.NONE or unit.inventory.has_item(rs.get_item_type()):
			unit.inventory.swap_resource_type(rs.resource.type)
			if unit.inventory.resource.amount < unit.inventory.resource_limit and rs.resource.amount > 0:
				rs.unit_interaction(unit)
				return

	elif target is Building:
		var b := target as Building
		if not b.construction_complete:
			b.start_construction()
		else:
			b.unit_interaction(unit)
	
	finished.emit()
