class_name CameraRig extends Node3D

signal landed

# Nodes.
@export var user: User
@export var wind_sound: AudioStream
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
var wind := AudioStreamPlayer.new()

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
var third_person_camera: ThirdPersonCamera

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
	third_person_camera = ThirdPersonCamera.new()
	wind.stream = wind_sound
	add_child(wind)

# Called by User to update Camera Rig.
func _physics_process(delta: float) -> void:
	mouse_current_position = get_viewport().get_mouse_position()
	match current_mode:
		MODE.RTS:
			rts_camera.physics_update(self, delta)
		MODE.UNIT_FOLLOW:
			follow_camera.physics_update(self, delta)
		MODE.UNIT_CONTROL:
			third_person_camera.physics_update(self, delta)

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

func take_over(target: Unit) -> void:
	stop_following()
	unit = target
	Units.pin(unit, Unit.Detail.FULL)
	unit.tree_exiting.connect(_on_unit_lost, CONNECT_ONE_SHOT)
	current_mode = MODE.UNIT_CONTROL
	third_person_camera.fly_in(self)

func leave() -> void:
	third_person_camera.fly_out(self)

# Called by the third-person camera once it has flown back out.
func land() -> void:
	_release_unit()
	rts_camera.camera_current_zoom = user.position.y
	current_mode = MODE.RTS
	landed.emit()

func _on_unit_lost() -> void:
	_release_unit()
	leave()

func _release_unit() -> void:
	if not unit: return
	if unit.tree_exiting.is_connected(_on_unit_lost): unit.tree_exiting.disconnect(_on_unit_lost)
	Units.unpin(unit)
	unit = null
