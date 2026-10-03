class_name Unit extends Node3D

# Longest a pathing unit goes without thinking, so a navigation map change is picked up.
const FALLBACK_THINK := 1.0
const DORMANT_JUMP := 2.0 # Longest a Dormant unit goes between jumps along its path.
const MAX_THINK_PASSES := 3
const MAX_BEND := 0.75 # How far separation can turn a walking unit, against its heading of length 1.
const STEP_ASIDE_SPEED := 4.0 # A standing unit's speed when pushed all the way.
const PUSH_DEAD_ZONE := 0.1 # A standing unit ignores a smaller push, so a settled crowd stands still.
const GROUND_MARGIN := 0.15 # A Full unit this close above the heightmap is on the ground.
const STOPPED_SPEED := 0.1 # A standing Full unit slower than this puts its body to sleep.
const ACCELERATION := 400.0 # And braking, of a Full unit's body: full speed in 25 ms, so it keeps pace with units without a body.

enum Detail { FULL, REDUCED, DORMANT }

# Components.
@export var selectable: SelectableObject
var path_finder: PathFinder
var think_task: ThinkTask
var detail := Detail.REDUCED # No body until Units sets the unit's level.
var registry_index := -1
var acting_index := -1
var grid_handle := -1
var body: RigidBody3D # From the Units pool while the unit is Full.

# Jobs.
var current_job: Job

# Selection.
signal selected(value: bool)
@export var portrait: Texture2D
var group_num: int = -1

# Allow Commands to be given to unit.
var command: UnitCommand
var command_queue: Array[UnitCommand]

# Pathing used with PathFinder.
var pathing: bool = false

# Movement.
@export_group("Stats")
@export var base_speed: float = 5.0
@export var turn_speed: float = 10.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 3.0
@export var jump_height: float = 3.0
@export var current_speed: float = 10

# Inventory
var inventory: Inventory = Inventory.new()

var height: float = 2.0
var radius := 0.5 # Of the body's capsule.
var reach := 1.5 # How close the unit has to be to a building's area to interact with it.
var push := Vector2.ZERO # Away from the unit's neighbours, from Units.
var velocity := Vector3.ZERO

static var _controller := UnitController.new()

var _yaw := 0.0
var _thinking := false
var _rethink := false

static func _static_init() -> void:
	_controller.acceleration = ACCELERATION
	_controller.braking = ACCELERATION

func _init() -> void:
	path_finder = PathFinder.new(self)

func _ready() -> void:
	select(false)

func _enter_tree() -> void:
	think_task = Scheduler.add(think, INF)
	_snap_to_ground()
	Units.register(self)
	if command or pathing: wake()

func _exit_tree() -> void:
	Scheduler.remove(think_task)
	think_task = null
	if body:
		_detach_body()
		detail = Detail.REDUCED
	Units.unregister(self)

# Called every tick by Units while the unit isn't Dormant.
func act(delta: float, heightmap: Heightmap) -> void:
	if body: _act_full(delta, heightmap)
	else: _act_reduced(delta, heightmap)

# The unit follows its body, and drives the body toward the steered velocity. A standing unit's body sleeps.
func _act_full(delta: float, heightmap: Heightmap) -> void:
	var asleep := body.sleeping
	if not asleep:
		var xform := body.global_transform
		global_transform = xform
		_yaw = atan2(xform.basis.z.x, xform.basis.z.z)
	var move := _steer()
	if move == Vector2.ZERO and asleep:
		velocity = Vector3.ZERO
		return
	var pos := global_position
	var grounded := not heightmap or pos.y - height * 0.5 <= heightmap.height_at(pos.x, pos.z) + GROUND_MARGIN
	var current := body.linear_velocity
	if move == Vector2.ZERO and grounded and current.x * current.x + current.z * current.z < STOPPED_SPEED * STOPPED_SPEED:
		body.sleeping = true
		velocity = Vector3.ZERO
		return
	if asleep: body.sleeping = false
	_controller.max_speed = current_speed
	_controller.turn_speed = turn_speed
	_controller.desired_velocity = Vector3(move.x, 0.0, move.y)
	_controller.desired_yaw = path_finder.desired_yaw if path_finder.desired_velocity != Vector3.ZERO else _yaw
	velocity = _controller.next_velocity(current, grounded, delta)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(0.0, _controller.yaw_rate(_yaw), 0.0)

# No body: the unit moves itself and stands on the heightmap.
func _act_reduced(delta: float, heightmap: Heightmap) -> void:
	var move := _steer()
	velocity = Vector3(move.x, 0.0, move.y)
	if move == Vector2.ZERO: return
	var pos := global_position + velocity * delta
	if heightmap: pos.y = heightmap.height_at(pos.x, pos.z) + height * 0.5
	if path_finder.desired_velocity != Vector3.ZERO: _yaw = lerp_angle(_yaw, path_finder.desired_yaw, minf(turn_speed * delta, 1.0))
	global_transform = Transform3D(Basis(Vector3.UP, _yaw), pos)

# This tick's horizontal velocity: a walking unit keeps its speed and bends away from its neighbours; a standing one steps aside.
func _steer() -> Vector2:
	if pathing: path_finder.steer()
	var desired := path_finder.desired_velocity
	if desired != Vector3.ZERO:
		var heading := Vector2(desired.x, desired.z).normalized()
		return (heading + _bend(heading)).normalized() * current_speed
	if push.length_squared() > PUSH_DEAD_ZONE * PUSH_DEAD_ZONE: return push.limit_length(1.0) * STEP_ASIDE_SPEED
	return Vector2.ZERO

# Separation turns a walking unit aside, never back: a push against its heading becomes one to the side the push
# already leans to, or to the right when it's straight back, so two units meeting head on pass each other.
func _bend(heading: Vector2) -> Vector2:
	var back := push.dot(heading)
	if back >= 0.0: return push.limit_length(MAX_BEND)
	var side := Vector2(-heading.y, heading.x)
	var lateral := push.dot(side)
	return side * clampf(lateral - back if lateral >= 0.0 else lateral + back, -MAX_BEND, MAX_BEND)

# A wake during the think (a leg ended, a command finished) runs another pass now instead of a think next tick.
func think(delta: float) -> void:
	_thinking = true
	for i in MAX_THINK_PASSES:
		_rethink = false
		if detail == Detail.DORMANT and pathing:
			path_finder.jump()
			Units.moved(self)
		path_finder.think()
		if current_job: current_job.think(self, delta)
		if command: command.think(self, delta)
		delta = 0.0
		if not _rethink: break
	_thinking = false
	if _rethink: wake()
	if not think_task or think_task.is_scheduled(): return
	var next := command.next_think(self) if command else INF
	if pathing: next = minf(next, path_finder.time_to_arrival(DORMANT_JUMP) if detail == Detail.DORMANT else FALLBACK_THINK)
	Scheduler.schedule_in(think_task, next)

func wake() -> void:
	if _thinking: _rethink = true
	elif think_task: Scheduler.wake(think_task)

# Full units move a pooled RigidBody3D, Reduced units move themselves on the heightmap, Dormant units jump along
# their path on think. A promoted unit keeps its walking velocity.
func set_detail(level: Detail) -> void:
	if level == detail: return
	var was := detail
	detail = level
	if was == Detail.FULL: _detach_body()
	if level == Detail.DORMANT: _park()
	elif was == Detail.DORMANT: _unpark()
	if level == Detail.FULL: _attach_body()

func _attach_body() -> void:
	body = Units.take_body()
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), global_position)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false

# The unit keeps the transform it last copied from its body, a tick behind the body, so it doesn't hop ahead.
func _detach_body() -> void:
	velocity = Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	Units.return_body(body)
	body = null

func _park() -> void:
	push = Vector2.ZERO
	path_finder.start_jumping()

func _unpark() -> void:
	if pathing: path_finder.jump()
	_snap_to_ground()
	reset_physics_interpolation()

func _snap_to_ground() -> void:
	var map := Map.current
	if map: global_position.y = map.get_heightmap().height_at(global_position.x, global_position.z) + height * 0.5

func _on_command_finished() -> void:
	set_command(null)

# Whether the unit's reach touches `node`: a building's area, or else its position. `slack` extends the reach.
func is_at(node: Node3D, slack := 0.0) -> bool:
	if node is Building: return (node as Building).in_reach(global_position, reach + slack)
	var to := node.global_position - global_position
	return Vector2(to.x, to.z).length() <= reach + slack

# Select Unit and emit selected signal.
func select(value: bool) -> void:
	selectable.is_selected = value
	selected.emit(value)

# Create UnitCard with information for this Unit and given index.
func create_unit_card(index: int) -> UnitCard:
	var unit_card := Global.UNIT_CARD.instantiate() as UnitCard
	unit_card.setup(index, self)

	return unit_card

# Back to a new unit's state, for reuse through Units.release.
func reset() -> void:
	set_job(null)
	clear_commands()
	path_finder.end_pathing()
	inventory.unequip(self)
	inventory = Inventory.new()
	velocity = Vector3.ZERO
	push = Vector2.ZERO
	_yaw = 0.0
	select(false)
	group_num = -1

func set_group_num(num: int) -> void:
	group_num = num

func set_job(job: Job) -> void:
	if current_job and current_job != job: current_job.teardown(self)
	current_job = job
	if current_job: current_job.start_schedule(self)

func clear_commands() -> void:
	command_queue.clear()
	set_command(null)

func set_command(cmnd: UnitCommand) -> void:
	if command: # Disconnect and exit current command.
		command.finished.disconnect(Callable(_on_command_finished))
		command.exit(self)
	command = cmnd
	if command: # Connect and enter next command.
		command.finished.connect(Callable(_on_command_finished))
		command.enter(self)
	elif command_queue.size() > 0: set_command(command_queue.pop_front()) # Next command in queue.
	elif current_job: set_command(current_job.next_command()) # Next command for current job.
	wake()
