class_name Unit extends CharacterBody3D

# Longest a pathing unit goes without thinking, so a navigation map change is picked up.
const FALLBACK_THINK := 1.0
const DORMANT_JUMP := 2.0 # Longest a Dormant unit goes between jumps along its path.
const MAX_THINK_PASSES := 3
const SNAP_RAY := 50.0

enum Detail { FULL, REDUCED, DORMANT }

# Nodes.
@onready var interaction_area: Area3D = $Area3D

# Components.
@export var selectable: SelectableObject
@export var avoidance_agent: NavigationAgent3D
@export var flock_agent: FlockAgent
var path_finder: PathFinder
var think_task: ThinkTask
var detail := Detail.FULL
var registry_index := -1

# Jobs.
var current_job: Job

# Selection.
signal selected(value: bool)
@export var portrait: Texture2D
var group_num: int = -1

# Allow Commands to be given to unit.
var command: UnitCommand
var command_queue: Array[UnitCommand]

var nearby_bodies: Array[Node3D]

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
var reach := 1.5 # Radius of the interaction area.

static var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _avoidance_moving := false
var _thinking := false
var _rethink := false

func _init() -> void:
	path_finder = PathFinder.new(self)

func _ready() -> void:
	select(false)

	var area_shape := (interaction_area.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	if area_shape: reach = area_shape.radius
	interaction_area.area_entered.connect(Callable(_on_interaction_area_entered))
	interaction_area.area_exited.connect(Callable(_on_interaction_area_exited))
	avoidance_agent.velocity_computed.connect(Callable(_on_velocity_computed))

func _enter_tree() -> void:
	think_task = Scheduler.add(think, INF)
	Units.register(self)
	if command or pathing: wake()

func _exit_tree() -> void:
	Scheduler.remove(think_task)
	think_task = null
	Units.unregister(self)

func _physics_process(delta: float) -> void:
	steer(delta)
	#flock_agent.physics_update(delta)
	if is_on_floor() and velocity.x == 0.0 and velocity.z == 0.0: return
	move_and_slide()

func steer(delta: float) -> void:
	if pathing: path_finder.steer()
	var desired := path_finder.desired_velocity
	if avoidance_agent.avoidance_enabled:
		if desired != Vector3.ZERO or _avoidance_moving: NavigationServer3D.agent_set_velocity(avoidance_agent.get_rid(), desired)
		_avoidance_moving = desired != Vector3.ZERO
	else:
		velocity.x = desired.x
		velocity.z = desired.z
	if desired != Vector3.ZERO: rotation.y = lerp_angle(rotation.y, path_finder.desired_yaw, minf(turn_speed * delta, 1.0))
	if not is_on_floor(): velocity.y -= gravity * delta

# A wake during the think (a leg ended, a command finished) runs another pass now instead of a think next tick.
func think(delta: float) -> void:
	_thinking = true
	for i in MAX_THINK_PASSES:
		_rethink = false
		if detail == Detail.DORMANT and pathing: path_finder.jump()
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

# Reduced behaves like Full until Phase 2 gives it a cheaper mover.
func set_detail(level: Detail) -> void:
	if level == detail: return
	var was_dormant := detail == Detail.DORMANT
	detail = level
	if level == Detail.DORMANT: _park()
	elif was_dormant: _unpark()

# Dormant units leave the physics space (body, area and avoidance) and jump along their path on think.
# nearby_bodies keeps what the unit stood at; jumping away clears it and arriving adds the leg's target.
func _park() -> void:
	var near := nearby_bodies.duplicate()
	process_mode = PROCESS_MODE_DISABLED
	nearby_bodies = near
	NavigationServer3D.agent_set_paused(avoidance_agent.get_rid(), true) # A unit that enters the tree parked isn't paused by the agent itself.
	path_finder.start_jumping()

func _unpark() -> void:
	if pathing: path_finder.jump()
	nearby_bodies.clear() # The area refills it on the next physics step.
	_snap_to_ground()
	NavigationServer3D.agent_set_paused(avoidance_agent.get_rid(), false)
	process_mode = PROCESS_MODE_INHERIT

func _snap_to_ground() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * SNAP_RAY, global_position + Vector3.DOWN * SNAP_RAY,
		1 << (Global.COLLISION_LAYER.TERRAIN - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit: global_position.y = hit.position.y + height * 0.5

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	var horizontal := Vector3(safe_velocity.x, 0.0, safe_velocity.z)
	if path_finder.desired_velocity != Vector3.ZERO and horizontal != Vector3.ZERO: horizontal = horizontal.normalized() * current_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z

func _on_command_finished() -> void:
	set_command(null)

# Keep track of all nearby Node3Ds in interaction_area and append to nearby_bodies array.
func _on_interaction_area_entered(body: Node3D) -> void:
	var node: Node3D = body.get_parent()
	nearby_bodies.append(node)
	if command: command.on_nearby_entered(self, node)

# Remove all Node3Ds from nearby_bodies array that leave interaction_area.
func _on_interaction_area_exited(body: Node3D) -> void:
	var node: Node3D = body.get_parent()
	if nearby_bodies.has(node):
		nearby_bodies.erase(node)

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
	nearby_bodies.clear()
	inventory.unequip(self)
	inventory = Inventory.new()
	velocity = Vector3.ZERO
	_avoidance_moving = false
	NavigationServer3D.agent_set_velocity(avoidance_agent.get_rid(), Vector3.ZERO)
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
