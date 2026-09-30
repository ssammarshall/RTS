extends Node
# Unit registry and simulation detail levels. A round robin over the registry compares each unit with the camera:
# Full in view within FULL_DISTANCE, Reduced in view further out or off screen within NEAR_DISTANCE, Dormant otherwise.
# Promotions happen at once, demotions after DEMOTE_DELAY; both stop for the tick once the transition budget is used.

const CHECKS_PER_TICK := 200
const FULL_DISTANCE := 80.0
const NEAR_DISTANCE := 120.0
const DEMOTE_DELAY := 1.0

var transition_budget_usec := 1000

# Stats for the harness.
var busy_usec := 0
var transitions := 0

var units: Array[Unit] = []
var _demote_at := PackedInt64Array() # Tick from which the unit may drop a level; -1 while it wants its current one.
var _next := 0

func _ready() -> void:
	process_physics_priority = -999

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
	var camera := get_viewport().get_camera_3d()
	if units.is_empty() or not camera: return
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
		elif transition_usec < transition_budget_usec and (wanted < unit.detail or Scheduler.tick >= _demote_at[_next]):
			var t := Time.get_ticks_usec()
			unit.set_detail(wanted)
			transition_usec += Time.get_ticks_usec() - t
			transitions += 1
			_demote_at[_next] = -1
		_next += 1
	busy_usec += Time.get_ticks_usec() - start

func _wanted_detail(pos: Vector3, camera: Camera3D, eye: Vector3) -> Unit.Detail:
	var distance := pos.distance_squared_to(eye)
	if camera.is_position_in_frustum(pos):
		return Unit.Detail.FULL if distance <= FULL_DISTANCE * FULL_DISTANCE else Unit.Detail.REDUCED
	return Unit.Detail.REDUCED if distance <= NEAR_DISTANCE * NEAR_DISTANCE else Unit.Detail.DORMANT
