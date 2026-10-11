class_name CameraRig extends Node3D

# Nodes.
@export var user: User
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

enum MODE {
	RTS,
	UNIT_FOLLOW,
	UNIT_CONTROL
}
var current_mode: MODE = MODE.RTS:
	set(new_mode):
		current_mode = new_mode
		match current_mode:
			MODE.RTS, MODE.UNIT_FOLLOW:
				spring_arm.spring_length = 0

# Modules.
var rts_camera: RTSCamera
var follow_camera: FollowCamera

# Universal.
var unit: Unit
var shift: bool = false
var mouse_current_position: Vector2
var mouse_last_position: Vector2 = Vector2.ZERO
var mouse_offset: Vector2
var mouse_sens: float = 0.15

# Camera movement.
var movement_direction: Vector3
var forward: bool = false
var backward: bool = false
var left: bool = false
var right: bool = false
var camera_can_move: bool = true

# Camera zoom.
var camera_can_zoom: bool = true

# Camera rotation.
var camera_can_rotate: bool = true

func _ready() -> void:
	rts_camera = RTSCamera.new()
	follow_camera = FollowCamera.new()

# Called by User to update Camera Rig.
func _physics_process(delta: float) -> void:
	match current_mode:
		MODE.RTS:
			rts_camera.physics_update(self, delta)
		MODE.UNIT_FOLLOW:
			follow_camera.physics_update(self, delta)

func set_mode(_mode: MODE) -> void:
	current_mode = _mode

func follow(target: Unit) -> void:
	stop_following()
	unit = target
	Units.pin(unit, Unit.Detail.REDUCED)
	unit.tree_exiting.connect(stop_following, CONNECT_ONE_SHOT)
	follow_camera.start(self)
	current_mode = MODE.UNIT_FOLLOW

func stop_following() -> void:
	if current_mode != MODE.UNIT_FOLLOW: return
	if unit.tree_exiting.is_connected(stop_following): unit.tree_exiting.disconnect(stop_following)
	Units.unpin(unit)
	unit = null
	rts_camera.camera_current_zoom = user.position.y
	current_mode = MODE.RTS
