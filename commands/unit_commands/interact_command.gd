class_name InteractCommand extends UnitCommand

const INTERACT_INTERVAL := 1.0 / 60.0

var target: Node3D
var from: Node3D
var _route_key := ""
var _elapsed: float = 0.0
var _arrived := false

func _init(_target: Node3D, _from: Node3D = null) -> void:
	target = _target
	from = _from
	assert(target != null)

# Called once UnitCommand is set to active command.
func enter(unit: Unit) -> void:
	_elapsed = 0.0
	_arrived = false
	if unit.nearby_bodies.has(target): return
	var route := ""
	if is_instance_valid(from) and unit.nearby_bodies.has(from):
		if _route_key.is_empty(): _route_key = RouteCache.key(from, target)
		route = _route_key
	unit.path_finder.add_to_path_queue(target.global_position, route, target as Building)

# The first think at the target interacts once; after that, once per INTERACT_INTERVAL of elapsed time.
func think(unit: Unit, delta: float) -> void:
	if not is_instance_valid(target):
		finished.emit()
		return
	if not unit.nearby_bodies.has(target):
		_arrived = false
		return
	if _arrived:
		_elapsed += delta
	else:
		_arrived = true
		_elapsed = INTERACT_INTERVAL
	var times := floori(_elapsed / INTERACT_INTERVAL + 0.001)
	if times <= 0: return
	_elapsed -= times * INTERACT_INTERVAL
	interact(unit, times)

# While gathering, think again when the load is full: the interaction after the last gather finishes the command.
func next_think(unit: Unit) -> float:
	if not _arrived: return INF
	var remaining := 1
	if target is ResourceSpawn and unit.inventory.resource:
		remaining = maxi(unit.inventory.resource_limit - unit.inventory.resource.amount, 0) + 1
	return remaining * INTERACT_INTERVAL - _elapsed

func on_nearby_entered(unit: Unit, node: Node3D) -> void:
	if node == target: unit.wake()

# Called once UnitCommand is finished or changed.
func exit(unit: Unit) -> void:
	if unit.pathing: unit.path_finder.end_pathing()

# `times` interactions at once: gathering takes one resource per interaction; a building is used once.
func interact(unit: Unit, times := 1) -> void:
	if target is ResourceSpawn:
		if (target as ResourceSpawn).gather(unit, times): return

	elif target is Building:
		var b := target as Building
		if not b.construction_complete:
			b.start_construction()
		else:
			b.unit_interaction(unit)
	
	finished.emit()
