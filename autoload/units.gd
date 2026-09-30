extends Node
# Unit registry, simulation detail levels and spawning. A round robin over the registry compares each unit with the camera:
# Full in view within FULL_DISTANCE, Reduced in view further out or off screen within NEAR_DISTANCE, Dormant otherwise.
# Promotions happen at once, demotions after DEMOTE_DELAY. Spawns are queued and reuse released units of the same scene.
# Each tick, transitions and then spawns stop once budget_usec is used; at least one spawn runs per tick.

const CHECKS_PER_TICK := 200
const FULL_DISTANCE := 80.0
const NEAR_DISTANCE := 120.0
const DEMOTE_DELAY := 1.0

var budget_usec := 1000

# Stats for the harness.
var busy_usec := 0
var transitions := 0
var spawn_usec := 0
var spawned := 0
var reused := 0

var units: Array[Unit] = []
var _demote_at := PackedInt64Array() # Tick from which the unit may drop a level; -1 while it wants its current one.
var _next := 0
var _spawns: Array[Callable] = []
var _spawn_head := 0
var _pool := {} # Scene path -> released units of that scene.

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
	var camera := get_viewport().get_camera_3d()
	if camera and is_physics_processing(): unit.set_detail(_wanted_detail(unit.global_position, camera, camera.global_position))

func unregister(unit: Unit) -> void:
	var index := unit.registry_index
	var last := units.size() - 1
	units[index] = units[last]
	units[index].registry_index = index
	_demote_at[index] = _demote_at[last]
	units.resize(last)
	_demote_at.resize(last)
	unit.registry_index = -1

# Units per detail level, indexed by Unit.Detail.
func counts() -> PackedInt32Array:
	var result := PackedInt32Array([0, 0, 0])
	for unit in units: result[unit.detail] += 1
	return result

func _physics_process(_delta: float) -> void:
	var used := _update_details()
	if _spawn_head < _spawns.size(): _run_spawns(budget_usec - used)

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
