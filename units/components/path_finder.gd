class_name PathFinder extends RefCounted

const WAYPOINT_REACHED := 1.0

static var queries := 0

var unit: Unit
var target := Vector3.ZERO
var desired_velocity := Vector3.ZERO
var desired_yaw := 0.0

var _path := PackedVector3Array()
var _index := 0
var _queue: Array[Vector3] = []
var _needs_path := false
var _query_pending := false
var _map := RID()
var _map_iteration := -1

func _init(owner_unit: Unit) -> void:
	unit = owner_unit

func add_to_path_queue(pos: Vector3) -> void:
	if not unit.pathing: _start_leg(pos)
	elif not _queue.has(pos): _queue.append(pos)

func end_pathing() -> void:
	_queue.clear()
	_path = PackedVector3Array()
	_index = 0
	_needs_path = false
	desired_velocity = Vector3.ZERO
	unit.pathing = false
	unit.wake()

func think() -> void:
	if not unit.pathing: return
	if _needs_path or (_map.is_valid() and NavigationServer3D.map_get_iteration_id(_map) != _map_iteration):
		_request_path()

func steer() -> void:
	var pos := unit.global_position
	while _index < _path.size():
		var point := _path[_index]
		if Vector2(point.x - pos.x, point.z - pos.z).length_squared() > WAYPOINT_REACHED * WAYPOINT_REACHED: break
		_index += 1
	if _index >= _path.size():
		_finish_leg()
		return
	var next := _path[_index]
	var dir := Vector2(next.x - pos.x, next.z - pos.z).normalized()
	desired_velocity = Vector3(dir.x, 0.0, dir.y) * unit.current_speed
	desired_yaw = atan2(-dir.x, -dir.y)

# Until its path query has run, the unit walks straight at the target.
func _start_leg(pos: Vector3) -> void:
	target = pos
	_path = PackedVector3Array([pos])
	_index = 0
	unit.pathing = true
	_request_path()
	unit.wake()

func _request_path() -> void:
	_needs_path = true
	if _query_pending: return
	_query_pending = true
	Scheduler.defer(_query_path)

func _query_path() -> void:
	_query_pending = false
	if not _needs_path or not is_instance_valid(unit) or not unit.pathing or not unit.is_inside_tree(): return
	if not _map.is_valid(): _map = unit.get_world_3d().navigation_map
	queries += 1
	var path := NavigationServer3D.map_get_path(_map, unit.global_position, target, true)
	if path.is_empty(): return # Map not synced yet: keep walking straight, the next think asks again.
	_path = path
	_index = 0
	_needs_path = false
	_map_iteration = NavigationServer3D.map_get_iteration_id(_map)

func _finish_leg() -> void:
	if _queue.is_empty(): end_pathing()
	else: _start_leg(_queue.pop_front())
