class_name InteractCommand extends UnitCommand

const INTERACT_INTERVAL := 1.0 / 60.0

var target: Node3D
var _elapsed: float = 0.0
var _arrived := false

func _init(_target: Node3D) -> void:
	target = _target
	assert(target != null)

# Called once UnitCommand is set to active command.
func enter(unit: Unit) -> void:
	_elapsed = 0.0
	_arrived = false
	if not unit.nearby_bodies.has(target): unit.path_finder.add_to_path_queue(target.global_position)

# The first think at the target interacts once; after that, once per INTERACT_INTERVAL of elapsed time.
func think(unit: Unit, delta: float) -> void:
	if not unit.nearby_bodies.has(target):
		_arrived = false
		return
	if _arrived:
		_elapsed += delta
	else:
		_arrived = true
		_elapsed = INTERACT_INTERVAL
	while _elapsed >= INTERACT_INTERVAL and unit.command == self:
		_elapsed -= INTERACT_INTERVAL
		interact(unit)

# While gathering, think again when the load is full (the last interaction finishes the command).
func next_think(unit: Unit) -> float:
	if not _arrived: return INF
	var remaining := 1
	if target is ResourceSpawn and unit.inventory.resource:
		remaining = maxi(unit.inventory.resource_limit - unit.inventory.resource.amount, 1)
	return remaining * INTERACT_INTERVAL - _elapsed

func on_nearby_entered(unit: Unit, node: Node3D) -> void:
	if node == target: unit.wake()

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
