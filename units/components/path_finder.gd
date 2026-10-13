class_name PathFinder extends RefCounted

const WAYPOINT_REACHED := 1.0
const JOIN_DISTANCE := 3.0
const ARRIVAL_DEPTH := 0.1 # The arrival point is this far inside the unit's reach rather than on its edge.
const ARRIVAL_REACHED := 0.5 # A walking unit whose reach never touches the target stops this close to the path's end.
const ARRIVAL_NEAR := 3.0 # Within this of the arrival point a walking unit checks its reach every tick (it cuts corners).

static var queries := 0
static var legs := 0
static var straight_legs := 0 # Legs that ended before their path query ran.
static var repaths := 0 # After a re-bake.

var unit: Unit
var target := Vector3.ZERO
var desired_velocity := Vector3.ZERO
var desired_yaw := 0.0
var jumped := 0.0 # How far a Dormant unit has jumped along this leg; -INF if it walked part of it.

var _path := PackedVector3Array()
var _index := 0
var _queue: Array[Vector3] = []
var _needs_path := false
var _query: PathQuery
var _route := "" # RouteCache key of this leg, empty for one-off legs.
var _reach: Building # The leg's target: the leg ends where the unit's reach first touches it.
var _waiting_for := "" # RouteCache key this finder waits on.
var _tiles := Rect2i()
var _change := 0
var _jump_tick := 0
var _arrival_index := -1
var _arrival_point := Vector3.ZERO
var _arrival_touches := false # Whether the unit's reach touches the target on the way, at _arrival_point.

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
	_query = null
	_route = ""
	_reach = null
	desired_velocity = Vector3.ZERO
	unit.pathing = false
	unit.wake()

func think() -> void:
	if not unit.pathing: return
	if _needs_path or _rebaked(): _request_path()

# Whether the map has merged a re-bake of a tile under the path since it was found.
func _rebaked() -> bool:
	var grid := Map.current.nav_grid
	if _change == grid.changes: return false
	if grid.changed_since(_tiles, _change):
		repaths += 1
		return true
	_change = grid.changes
	return false

# A leg with a target ends once the unit's reach touches it, on the way to _arrival_point.
func steer() -> void:
	var pos := unit.global_position
	var reach_leg := is_instance_valid(_reach)
	if reach_leg and _arrival_index < 0: _find_arrival()
	var followed := _arrival_index if reach_leg else _path.size()
	while _index < followed:
		var point := _path[_index]
		if Vector2(point.x - pos.x, point.z - pos.z).length_squared() > WAYPOINT_REACHED * WAYPOINT_REACHED: break
		_index += 1
	var next: Vector3
	if reach_leg:
		var heading := _index >= followed
		var to_arrival := Vector2(_arrival_point.x - pos.x, _arrival_point.z - pos.z).length_squared()
		if (heading or to_arrival <= ARRIVAL_NEAR * ARRIVAL_NEAR) and _reach.in_reach(pos, unit.reach) \
				or heading and not _arrival_touches and to_arrival <= ARRIVAL_REACHED * ARRIVAL_REACHED:
			_arrive()
			return
		next = _arrival_point if heading else _path[_index]
	elif _index < followed:
		next = _path[_index]
	else:
		_finish_leg()
		return
	var dir := Vector2(next.x - pos.x, next.z - pos.z).normalized()
	desired_velocity = Vector3(dir.x, 0.0, dir.y) * unit.current_speed
	desired_yaw = atan2(-dir.x, -dir.y)

# Jumps count from `ticks_ago`: a leg a Dormant unit has been walking that long. The leg isn't jumped whole.
func start_jumping(ticks_ago := 0) -> void:
	_jump_tick = Scheduler.tick - ticks_ago
	_arrival_index = -1
	jumped = -INF

# A Dormant unit moves as far along its path as it would have walked since the last jump.
func jump() -> void:
	var distance := (Scheduler.tick - _jump_tick) * unit.current_speed / Engine.physics_ticks_per_second
	_jump_tick = Scheduler.tick
	if distance <= 0.0: return
	if _arrival_index < 0: _find_arrival()
	var pos := unit.global_position
	var lift := Vector3.UP * unit.height * 0.5
	var budget := distance
	while true:
		var point := _arrival_point if _index >= _arrival_index else _path[_index] + lift
		var step := Vector2(point.x - pos.x, point.z - pos.z).length()
		if step > distance:
			unit.global_position = pos.lerp(point, distance / step)
			jumped += budget
			return
		distance -= step
		pos = point
		if _index >= _arrival_index: break
		_index += 1
	unit.global_position = pos
	jumped += budget - distance
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

# Where the unit arrives: where its reach would first touch the leg's target, or the end of the path. Found once per
# path: walking or jumping, the unit follows the points before _arrival_index, then goes to _arrival_point.
func _find_arrival() -> void:
	var pos := unit.global_position
	var lift := Vector3.UP * unit.height * 0.5
	_arrival_index = maxi(_path.size() - 1, _index)
	_arrival_point = _path[_path.size() - 1] + lift if not _path.is_empty() else pos
	_arrival_touches = false
	for i in range(_index, _path.size()):
		var point := _path[i] + lift
		var reach := _reach.reach_along(pos, point, unit.reach - ARRIVAL_DEPTH) if is_instance_valid(_reach) else -1.0
		if reach >= 0.0:
			_arrival_index = i
			_arrival_point = pos.lerp(point, reach)
			_arrival_touches = true
			return
		pos = point

func _arrive() -> void:
	_index = _path.size()
	_finish_leg()

func is_active() -> bool:
	return is_instance_valid(unit) and unit.pathing and unit.is_inside_tree()

func take_route(route_key: String, route: RouteCache.Route) -> void:
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
	_query = null
	_route = route
	_reach = reach
	_jump_tick = Scheduler.tick
	jumped = 0.0 if unit.detail == Unit.Detail.DORMANT else -INF
	unit.pathing = true
	_request_path(true)
	unit.wake()

func _request_path(leg_start := false) -> void:
	_needs_path = true
	if not _route.is_empty():
		if _waiting_for == _route: return
		if _use_route(leg_start): return
		_route = ""
	if _query: return
	queries += 1
	_query = PathQuery.request(unit.global_position, target, _take_path)

# Joins a shared route near the unit, or waits for one being queried. Only a unit at the start of its leg may start a query.
func _use_route(leg_start: bool) -> bool:
	for route: RouteCache.Route in RouteCache.get_routes(_route):
		if _join(route): return true
	if not RouteCache.is_querying(_route) and (not leg_start or RouteCache.is_full(_route)): return false
	_waiting_for = _route
	RouteCache.request(_route, unit.global_position, target, self)
	return true

# Continues from the route's segment closest to the unit, if that is within JOIN_DISTANCE. RouteCache's routes are up
# to date with the map.
func _join(shared: RouteCache.Route) -> bool:
	if not shared: return false
	var route := shared.path
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
	_tiles = shared.tiles
	_change = Map.current.nav_grid.changes
	return true

# A query from an earlier leg was dropped when this one started. One requested before a re-bake under its path reached
# the map makes the next think re-path.
func _take_path(query: PathQuery) -> void:
	if query != _query: return
	_query = null
	if not _needs_path or not _route.is_empty() or not is_active(): return # A shared route's leg gets its path from RouteCache.
	if query.path.is_empty(): return # Map not synced yet: keep walking straight, the next think asks again.
	_path = query.path
	_index = 0
	_arrival_index = -1
	_needs_path = false
	_tiles = Map.current.nav_grid.tiles_under(_path)
	_change = query.change

func _finish_leg() -> void:
	if _queue.is_empty(): end_pathing()
	else: _start_leg(_queue.pop_front())
