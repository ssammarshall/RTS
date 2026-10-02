extends Node
# Unit registry, simulation detail levels, spawning and the act step. A round robin over the registry compares each unit with the camera:
# Full in view within FULL_DISTANCE, Reduced in view further out or off screen within NEAR_DISTANCE, Dormant otherwise.
# Promotions happen at once, demotions after DEMOTE_DELAY. Spawns are queued and reuse released units of the same scene.
# Each tick, transitions and then spawns stop once budget_usec is used; at least one spawn runs per tick.
# Then every unit that isn't Dormant acts (steers and moves), from one loop. Every unit is in `grid` at its last position.
# Units don't collide with each other: each acting unit takes a push away from its grid neighbours every `separation_ticks`.

const CHECKS_PER_TICK := 200
const FULL_DISTANCE := 80.0
const NEAR_DISTANCE := 120.0
const DEMOTE_DELAY := 1.0
const GRID_CELL := 8.0
const PICK_HEIGHT := 2.5 # Picking looks along the mouse ray where it's lower than this above the ground.
const SEPARATION := 1.2 # Units whose centres are closer than this push apart: two radii and a gap.

var budget_usec := 1000
var separation_ticks := 2
var detail_enabled := true
var act_enabled := true # Off while the harness runs and times the act step itself.
var separation_enabled := true

# Stats for the harness.
var busy_usec := 0
var transitions := 0
var spawn_usec := 0
var spawned := 0
var reused := 0

var units: Array[Unit] = []
var acting: Array[Unit] = [] # The units that aren't Dormant.
var grid := SpatialGrid.new(GRID_CELL)
var _demote_at := PackedInt64Array() # Tick from which the unit may drop a level; -1 while it wants its current one.
var _next := 0
var _spawns: Array[Callable] = []
var _spawn_head := 0
var _pool := {} # Scene path -> released units of that scene.
var _picked: Array = []

func _ready() -> void:
	process_physics_priority = -999

func _exit_tree() -> void:
	for pool: Array in _pool.values():
		for unit: Unit in pool: unit.free()
	_pool.clear()

# Adds a unit of `scene` under `parent` at `position` within the next ticks; `on_spawned` gets it once it's in the tree.
func spawn(scene: PackedScene, parent: Node, position: Vector3, on_spawned := Callable()) -> void:
	_spawns.append(_spawn.bind(scene, parent, position, on_spawned))

func pending_spawns() -> int:
	return _spawns.size() - _spawn_head

# Takes the unit out of the tree and keeps it for the next spawn of its scene. Take it out of its groups first.
func release(unit: Unit) -> void:
	unit.reset()
	unit.get_parent().remove_child(unit)
	_pool.get_or_add(unit.scene_file_path, []).append(unit)

# A new unit starts at its level: registering happens before its body and area enter the physics space.
func register(unit: Unit) -> void:
	unit.registry_index = units.size()
	units.append(unit)
	_demote_at.append(-1)
	var pos := unit.global_position
	unit.grid_handle = grid.insert(unit, Vector2(pos.x, pos.z))
	var camera := get_viewport().get_camera_3d()
	if camera and detail_enabled: unit.set_detail(_wanted_detail(pos, camera, camera.global_position))
	_update_acting(unit)

func unregister(unit: Unit) -> void:
	var index := unit.registry_index
	var last := units.size() - 1
	units[index] = units[last]
	units[index].registry_index = index
	_demote_at[index] = _demote_at[last]
	units.resize(last)
	_demote_at.resize(last)
	unit.registry_index = -1
	if unit.acting_index >= 0: _remove_acting(unit)
	grid.remove(unit.grid_handle)
	unit.grid_handle = -1

# Re-files a unit moved outside the act loop.
func moved(unit: Unit) -> void:
	var pos := unit.global_position
	grid.move(unit.grid_handle, Vector2(pos.x, pos.z))

# The unit under `screen_pos`: of the units whose capsule the camera ray passes through, the nearest to the camera.
func pick(camera: Camera3D, screen_pos: Vector2) -> Unit:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit := Util.mouse_raycast(camera, screen_pos, 1 << (Global.COLLISION_LAYER.TERRAIN - 1))
	if hit.is_empty() or dir.y > -0.01: return null
	var ground: Vector3 = hit.position
	var top := origin + dir * maxf((ground.y + PICK_HEIGHT - origin.y) / dir.y, 0.0)
	var span := Vector2(top.x - ground.x, top.z - ground.z)
	grid.query_circle(Vector2(ground.x, ground.z) + span * 0.5, span.length() * 0.5 + 1.0, _picked)
	var far := ground + dir
	var best: Unit = null
	var best_distance := INF
	for unit: Unit in _picked:
		var axis := Vector3.UP * (unit.height * 0.5 - unit.radius)
		var center := unit.global_position
		var closest := Geometry3D.get_closest_points_between_segments(origin, far, center - axis, center + axis)
		if closest[0].distance_squared_to(closest[1]) > unit.radius * unit.radius: continue
		var distance := origin.distance_squared_to(closest[0])
		if distance < best_distance:
			best_distance = distance
			best = unit
	return best

# Units per detail level, indexed by Unit.Detail.
func counts() -> PackedInt32Array:
	var result := PackedInt32Array([0, 0, 0])
	for unit in units: result[unit.detail] += 1
	return result

func _physics_process(delta: float) -> void:
	var used := _update_details() if detail_enabled else 0
	if _spawn_head < _spawns.size(): _run_spawns(budget_usec - used)
	if act_enabled:
		var turn := Scheduler.tick % separation_ticks
		for unit in acting:
			if unit.acting_index % separation_ticks == turn:
				unit.push = grid.separation(unit.grid_handle, SEPARATION) if separation_enabled else Vector2.ZERO
			unit.act(delta)
			var pos := unit.global_position
			grid.move(unit.grid_handle, Vector2(pos.x, pos.z))

func _update_acting(unit: Unit) -> void:
	var acts := unit.detail != Unit.Detail.DORMANT
	if acts == (unit.acting_index >= 0): return
	if acts:
		unit.acting_index = acting.size()
		acting.append(unit)
	else: _remove_acting(unit)

func _remove_acting(unit: Unit) -> void:
	var last := acting[acting.size() - 1]
	acting[unit.acting_index] = last
	last.acting_index = unit.acting_index
	acting.resize(acting.size() - 1)
	unit.acting_index = -1

# Returns the time spent on transitions.
func _update_details() -> int:
	var camera := get_viewport().get_camera_3d()
	if units.is_empty() or not camera: return 0
	var start := Time.get_ticks_usec()
	var eye := camera.global_position
	var transition_usec := 0
	var demote_ticks := roundi(DEMOTE_DELAY * Engine.physics_ticks_per_second)
	for i in mini(CHECKS_PER_TICK, units.size()):
		if _next >= units.size(): _next = 0
		var unit := units[_next]
		var wanted := _wanted_detail(unit.global_position, camera, eye)
		if wanted == unit.detail:
			_demote_at[_next] = -1
		elif wanted > unit.detail and _demote_at[_next] < 0:
			_demote_at[_next] = Scheduler.tick + demote_ticks
		elif transition_usec < budget_usec and (wanted < unit.detail or Scheduler.tick >= _demote_at[_next]):
			var t := Time.get_ticks_usec()
			unit.set_detail(wanted)
			_update_acting(unit)
			transition_usec += Time.get_ticks_usec() - t
			transitions += 1
			_demote_at[_next] = -1
		_next += 1
	busy_usec += Time.get_ticks_usec() - start
	return transition_usec

func _run_spawns(budget: int) -> void:
	var start := Time.get_ticks_usec()
	while _spawn_head < _spawns.size():
		var request := _spawns[_spawn_head]
		_spawns[_spawn_head] = Callable()
		_spawn_head += 1
		request.call()
		if Time.get_ticks_usec() - start >= budget: break
	if _spawn_head == _spawns.size():
		_spawns.clear()
		_spawn_head = 0
	spawn_usec += Time.get_ticks_usec() - start

func _spawn(scene: PackedScene, parent: Node, position: Vector3, on_spawned: Callable) -> void:
	if not is_instance_valid(parent): return
	var pool: Array = _pool.get(scene.resource_path, [])
	var unit: Unit
	if pool.is_empty(): unit = scene.instantiate()
	else:
		unit = pool.pop_back()
		reused += 1
	unit.transform = Transform3D(Basis.IDENTITY, position)
	parent.add_child(unit)
	spawned += 1
	if on_spawned.is_valid(): on_spawned.call(unit)

func _wanted_detail(pos: Vector3, camera: Camera3D, eye: Vector3) -> Unit.Detail:
	var distance := pos.distance_squared_to(eye)
	if camera.is_position_in_frustum(pos):
		return Unit.Detail.FULL if distance <= FULL_DISTANCE * FULL_DISTANCE else Unit.Detail.REDUCED
	return Unit.Detail.REDUCED if distance <= NEAR_DISTANCE * NEAR_DISTANCE else Unit.Detail.DORMANT
