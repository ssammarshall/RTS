class_name PathFinder extends NavigationAgent3D

@export var unit: Unit

var target_direction: Vector3
var path_pos_queue: Array[Vector3]
var next_path_pos: Vector3

func _ready() -> void:
	set_debug_enabled(false)
	set_avoidance_enabled(true) # set to change when unit is given an order
	velocity_computed.connect(Callable(_on_velocity_computed))
	
	var timer := Timer.new()
	add_child(timer)
	timer.start(0.25)
	timer.set_one_shot(false) # Timer starts again after timing out.
	timer.timeout.connect(Callable(_on_timer_timeout))

# Called when the collision avoidance velocity is calculated.
func _on_velocity_computed(new_velocity: Vector3) -> void:
	unit.velocity = new_velocity.normalized() * unit.current_speed
	#print(new_velocity)

func _on_timer_timeout() -> void:
	if is_navigation_finished() and unit.pathing: # If current target position has been reached.
		find_next_path_pos()

func physics_update(delta: float) -> void:
	next_path_pos = get_next_path_position()
	if next_path_pos == Vector3.ZERO: return
	set_target_direction(next_path_pos) # Towards next path position.
	rotate_towards_target(target_direction,delta)
	# Set velocity of PathFinder.
	set_velocity(unit.velocity + (target_direction - unit.velocity) * unit.turn_speed * delta) # Method from NavigationAgent3D.

# Called when unit reaches target.
func find_next_path_pos() -> void:
	# Set next_path_pos if another position is path_pos_queue.
	if path_pos_queue.size() > 0:
		next_path_pos = path_pos_queue.pop_front() # Grab next path in queue.
		set_target_position(next_path_pos) # Method in NavigationAgent3D to create path to next_path_pos.
	# End pathing if no pos in queue.
	else: end_pathing()

# Set direction towards target position and create path to target.
func set_target_direction(target: Vector3) -> void:
	target_direction = unit.global_position.direction_to(target) * unit.current_speed

# Rotate unit to face toward target direction.
func rotate_towards_target(dir: Vector3, delta: float) -> void:
	if dir == Vector3.ZERO: return
	var pos_2D: Vector2 = Vector2(-unit.transform.basis.z.x, -unit.transform.basis.z.z)
	var goal_2D: Vector2 = Vector2(dir.x, dir.z)
	unit.rotation.y -= pos_2D.angle_to(goal_2D) * unit.turn_speed * delta

func add_to_path_queue(pos: Vector3) -> void:
	if !unit.pathing:
		next_path_pos = pos
		set_target_position(next_path_pos)
		unit.pathing = true
	elif path_pos_queue.has(pos): return
	else:path_pos_queue.append(pos)

func end_pathing() -> void:
	path_pos_queue.clear()
	set_target_position(unit.global_position)
	set_velocity(Vector3.ZERO)
	
	unit.pathing = false
