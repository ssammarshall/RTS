class_name PathFinder extends RefCounted

const WAYPOINT_REACHED := 1.0
const JOIN_DISTANCE := 3.0

static var queries := 0
static var legs := 0
static var straight_legs := 0 # Legs that ended before their path query ran.

var unit: Unit
var target := Vector3.ZERO
var desired_velocity := Vector3.ZERO
var desired_yaw := 0.0

var _path := PackedVector3Array()
var _index := 0
var _queue: Array[Vector3] = []
var _needs_path := false
var _query_pending := false
var _route := "" # RouteCache key of this leg, empty for one-off legs.
var _reach: Building # The leg's target: a Dormant unit arrives where its interaction area would touch it.
var _waiting_for := "" # RouteCache key this finder waits on.
var _map := RID()
var _map_iteration := -1
var _jump_tick := 0
var _arrival_index := -1
var _arrival_point := Vector3.ZERO

func _init(owner_unit: Unit) -> void:
	unit = owner_unit

# `route` shares the leg's path through RouteCache; the unit has to be standing at the route's from node.
func add_to_path_queue(pos: Vector3, route := "", reach: Building = null) -> void:
	if not unit.pathing: _start_leg(pos, route, reach)
	elif not _queue.has(pos): _queue.append(pos)

func end_pathing() -> void:
	if unit.pathing and _needs_path: straight_legs += 1
	_queue.clear()
	_path = PackedVector3Array()
	_index = 0
	_arrival_index = -1
	_needs_path = false
	_route = ""
	_reach = null
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

func start_jumping() -> void:
	_jump_tick = Scheduler.tick
	_arrival_index = -1

# A Dormant unit moves as far along its path as it would have walked since the last jump.
func jump() -> void:
	var distance := (Scheduler.tick - _jump_tick) * unit.current_speed / Engine.physics_ticks_per_second
	_jump_tick = Scheduler.tick
	if distance <= 0.0: return
	if _arrival_index < 0: _find_arrival()
	unit.nearby_bodies.clear()
	var pos := unit.global_position
	var lift := Vector3.UP * unit.height * 0.5
	while true:
		var point := _arrival_point if _index >= _arrival_index else _path[_index] + lift
		var step := Vector2(point.x - pos.x, point.z - pos.z).length()
		if step > distance:
			unit.global_position = pos.lerp(point, distance / step)
			return
		distance -= step
		pos = point
		if _index >= _arrival_index: break
		_index += 1
	unit.global_position = pos
	_arrive()

# Seconds until a Dormant unit arrives, capped at `limit`, so its next jump lands on arrival.
func time_to_arrival(limit: float) -> float:
	if _arrival_index < 0: _find_arrival()
	var pos := unit.global_position
	var lift := Vector3.UP * unit.height * 0.5
	var distance := 0.0
	for i in range(_index, _arrival_index):
		var point := _path[i] + lift
		distance += Vector2(point.x - pos.x, point.z - pos.z).length()
		pos = point
	distance += Vector2(_arrival_point.x - pos.x, _arrival_point.z - pos.z).length()
	return minf(distance / unit.current_speed, limit)

# Where a Dormant unit arrives: where its interaction area would first touch the leg's target, or the end of the path.
# Found once per path: the unit walks the points before _arrival_index, then to _arrival_point.
func _find_arrival() -> void:
	var pos := unit.global_position
	var lift := Vector3.UP * unit.height * 0.5
	_arrival_index = maxi(_path.size() - 1, _index)
	_arrival_point = _path[_path.size() - 1] + lift if not _path.is_empty() else pos
	for i in range(_index, _path.size()):
		var point := _path[i] + lift
		var reach := _reach.reach_along(pos, point, unit.reach) if is_instance_valid(_reach) else -1.0
		if reach >= 0.0:
			_arrival_index = i
			_arrival_point = pos.lerp(point, reach)
			return
		pos = point

func _arrive() -> void:
	if is_instance_valid(_reach) and not unit.nearby_bodies.has(_reach): unit.nearby_bodies.append(_reach)
	_index = _path.size()
	_finish_leg()

func is_active() -> bool:
	return is_instance_valid(unit) and unit.pathing and unit.is_inside_tree()

func take_route(route_key: String, route: PackedVector3Array) -> void:
	if _waiting_for == route_key: _waiting_for = ""
	if not is_active() or not _needs_path or _route != route_key: return
	if not _join(route): _request_path()

# Until its path query has run, the unit walks straight at the target.
func _start_leg(pos: Vector3, route := "", reach: Building = null) -> void:
	if unit.pathing and _needs_path: straight_legs += 1
	legs += 1
	target = pos
	_path = PackedVector3Array([pos])
	_index = 0
	_arrival_index = -1
	_route = route
	_reach = reach
	_jump_tick = Scheduler.tick
	unit.pathing = true
	_request_path(true)
	unit.wake()

func _request_path(leg_start := false) -> void:
	_needs_path = true
	if not _route.is_empty():
		if _waiting_for == _route: return
		if _use_route(leg_start): return
		_route = ""
	if _query_pending: return
	_query_pending = true
	Scheduler.defer(_query_path)

# Joins a shared route near the unit, or waits for one being queried. Only a unit at the start of its leg may start a query.
func _use_route(leg_start: bool) -> bool:
	var map := _nav_map()
	for route: PackedVector3Array in RouteCache.get_routes(_route, map):
		if _join(route): return true
	if not RouteCache.is_querying(_route) and (not leg_start or RouteCache.is_full(_route)): return false
	_waiting_for = _route
	RouteCache.request(_route, map, unit.global_position, target, self)
	return true

# Continues from the route's segment closest to the unit, if that is within JOIN_DISTANCE.
func _join(route: PackedVector3Array) -> bool:
	var pos := Vector2(unit.global_position.x, unit.global_position.z)
	var best := JOIN_DISTANCE * JOIN_DISTANCE
	var index := -1
	for i in route.size() - 1:
		var a := Vector2(route[i].x, route[i].z)
		var closest := Geometry2D.get_closest_point_to_segment(pos, a, Vector2(route[i + 1].x, route[i + 1].z))
		var distance := pos.distance_squared_to(closest)
		if distance < best:
			best = distance
			index = i if closest == a else i + 1
	if index < 0: return false
	_path = route
	_index = index
	_arrival_index = -1
	_needs_path = false
	_map_iteration = NavigationServer3D.map_get_iteration_id(_map)
	return true

func _query_path() -> void:
	_query_pending = false
	if not _needs_path or not _route.is_empty() or not is_active(): return # A shared route's leg gets its path from RouteCache.
	var map := _nav_map()
	queries += 1
	var path := NavigationServer3D.map_get_path(map, unit.global_position, target, true)
	if path.is_empty(): return # Map not synced yet: keep walking straight, the next think asks again.
	_path = path
	_index = 0
	_arrival_index = -1
	_needs_path = false
	_map_iteration = NavigationServer3D.map_get_iteration_id(map)

func _nav_map() -> RID:
	if not _map.is_valid(): _map = unit.get_world_3d().navigation_map
	return _map

func _finish_leg() -> void:
	if _queue.is_empty(): end_pathing()
	else: _start_leg(_queue.pop_front())
