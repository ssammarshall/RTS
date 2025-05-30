class_name RTSCamera extends CameraModule

# Camera movement.
@export_range(0,100,1) var camera_move_speed: float = 20.0

# Camera zoom.
@export_group("Camera Zoom")
@export_range(0,100,1) var camera_zoom_speed: float = 40.0
@export_range(0,2,0.1) var camera_zoom_speed_damp: float = 0.90
@export_range(0,100,1) var camera_zoom_max: float = 55.0
var camera_zoom_direction: float = 0.0
var camera_current_zoom: float = 0.0
var camera_zoom_slow_down: bool = true

# Camera pan.
var camera_can_auto_pan: bool = true
var camera_auto_pan_margin: int = 16
var camera_auto_pan_speed: float = 12

# Camera rotation.
@export_group("Camera Rotation")
@export_range(0,10,0.1) var camera_rotation_speed: float = 1.5
@export_range(0,10,1) var camera_rotation_x_min: float = -1.2
@export_range(0,10,1) var camera_rotation_x_max: float = -0.1
var camera_rotation_direction: int = 0
var camera_rotate_keypad: bool = false
var camera_rotate_mouse: bool = false:
	set(value):
		camera_rotate_mouse = value
		camera_can_auto_pan = !value # Temporarily disable auto pan when rotating camera with mouse.

# Camera focus.
var camera_focus_pos := Vector3.ZERO # DO NOT SET DIRECTLY. USE SET_CAMERA_FOCUS_POS().
var focus_rotation := 0.0
var camera_is_focused: bool = false

func physics_update(camera_rig: CameraRig, delta: float) -> void:
	camera_rig.mouse_current_position = camera_rig.get_viewport().get_mouse_position()
	if camera_is_focused:
		camera_focus(camera_rig, delta)
	else:
		camera_move(camera_rig, delta)
		camera_zoom(camera_rig, delta)
		camera_auto_pan(camera_rig, delta)
		camera_rotate(camera_rig, delta)

# Control camera movement.
func camera_move(camera_rig: CameraRig, delta: float) -> void:
	if not camera_rig.camera_can_move: return
	
	var speed_modifier: int # The lower the value the faster the move speed.
	if camera_rig.shift: speed_modifier = 5
	else: speed_modifier = 10
	
	camera_rig.movement_direction = Vector3.ZERO
	
	var user: User = camera_rig.user
	
	if camera_rig.forward: camera_rig.movement_direction -= user.transform.basis.z
	if camera_rig.backward: camera_rig.movement_direction += user.transform.basis.z
	if camera_rig.left: camera_rig.movement_direction -= user.transform.basis.x
	if camera_rig.right: camera_rig.movement_direction += user.transform.basis.x
	
	var speed = camera_move_speed * camera_current_zoom / speed_modifier
	
	camera_rig.movement_direction = camera_rig.movement_direction.normalized() * speed
	user.global_position += camera_rig.movement_direction * delta

# Control camera zoom.
func camera_zoom(camera_rig: CameraRig, delta: float) -> void:
	if not camera_rig.camera_can_zoom: return
	
	var user: User = camera_rig.user
	
	var new_zoom: float = user.position.y + camera_zoom_speed * camera_zoom_direction * delta / 2
	
	if new_zoom < 0 or new_zoom > camera_zoom_max: return
	
	user.position.y = lerpf(user.position.y, new_zoom, 0.7)
	camera_current_zoom = new_zoom
	
	if camera_zoom_slow_down:
		camera_zoom_direction *= camera_zoom_speed_damp

# Control camera auto panning with mouse.
func camera_auto_pan(camera_rig: CameraRig, delta: float) -> void:
	if not camera_can_auto_pan: return
	
	camera_rig.mouse_current_position = camera_rig.get_viewport().get_mouse_position()
	
	var viewport_visible_rectangle: Rect2i = Rect2i(camera_rig.get_viewport().get_visible_rect())
	var viewport_size: Vector2 = viewport_visible_rectangle.size
	
	var user: User = camera_rig.user
	
	var pan_direction: Vector2 = Vector2(-1,-1) # Starts negative (left,down).
	var zoom_factor: float = user.position.y * 0.1
	
	# X Pan.
	if camera_rig.mouse_current_position.x < camera_auto_pan_margin \
	or camera_rig.mouse_current_position.x > viewport_size.x - camera_auto_pan_margin:
		if camera_rig.mouse_current_position.x > viewport_size.x/2: # Check if on right side of screen.
			pan_direction.x = 1 # Move right.
		user.translate(Vector3(pan_direction.x * delta * camera_auto_pan_speed * zoom_factor, 0, 0))
	
	# Y Pan.
	if camera_rig.mouse_current_position.y < camera_auto_pan_margin \
	or camera_rig.mouse_current_position.y > viewport_size.y - camera_auto_pan_margin:
		if camera_rig.mouse_current_position.y > viewport_size.y/2: # Check if on top side of screen.
			pan_direction.y = 1 # Move forward.
		user.translate(Vector3(0, 0, pan_direction.y * delta * camera_auto_pan_speed * zoom_factor))

# Control camera rotation.
func camera_rotate(camera_rig: CameraRig, delta: float) -> void:
	if not camera_rig.camera_can_rotate: return
	
	var user: User = camera_rig.user
	
	# Rotate with mouse.
	if camera_rotate_mouse:
		# Rotate camera rig up and down.
		camera_rig.rotation.x -= camera_rig.mouse_offset.y * camera_rotation_speed * camera_rig.mouse_sens * delta
		camera_rig.rotation.x = clampf(camera_rig.rotation.x, camera_rotation_x_min, camera_rotation_x_max)
		
		# Rotate user left and right.
		user.rotation.y -= camera_rig.mouse_offset.x * camera_rotation_speed * camera_rig.mouse_sens * delta
		
		camera_rig.mouse_offset = Vector2.ZERO
		
		Util.check_mouse_margins(
			camera_rig.get_viewport(), 
			camera_rig.mouse_current_position)
	
	# Rotate with keypad.
	if camera_rotate_keypad:
		user.rotation.y += camera_rotation_direction * camera_rotation_speed * delta

# Transform camera to focus on a position.
func camera_focus(camera_rig: CameraRig, delta: float) -> void:
	if camera_focus_pos == Vector3.ZERO: return
	
	var user: User = camera_rig.user
	
	user.global_position = lerp(user.global_position, camera_focus_pos, delta * 2.5)
	user.rotation.y = lerp_angle(user.rotation.y, focus_rotation, delta * 2.5)
	
	var rotation_difference: float = absf(user.rotation.y - focus_rotation)
	if user.global_position.distance_to(camera_focus_pos) < 2 and rotation_difference < 0.1:
		camera_is_focused = false

# Also calculates focus_rotation and sets camera_is_focused.
func set_camera_focus_pos(camera_rig: CameraRig, pos: Vector3) -> void:
	var user: User = camera_rig.user
	
	if not user:
		camera_focus_pos = Vector3.ZERO
		return
	
	var direction_to_pos: Vector3 = user.global_position - pos
	
	camera_focus_pos = (direction_to_pos.normalized() * user.position.y) + pos
	if camera_focus_pos.y < 0: camera_focus_pos.y = 0
	
	var forward_direction := user.global_transform.basis.z
	var forward_2d := Vector2(forward_direction.x, forward_direction.z)
	var direction_to_pos_2d := Vector2(direction_to_pos.x, direction_to_pos.z)
	
	focus_rotation = forward_2d.angle_to(direction_to_pos_2d)
	focus_rotation = user.rotation.y - focus_rotation
	
	camera_is_focused = true


func follow_unit(camera_rig: CameraRig, u: Unit) -> void:
	if not u == null: camera_rig.unit = u
	else: return
