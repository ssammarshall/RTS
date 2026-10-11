class_name FollowCamera extends CameraModule
# Keeps the rig's unit at FRAME on screen, `distance` from the camera, whatever way the camera turns, so turning orbits
# the unit. Starting flies there over FLY_TIME without turning. Moving or edge panning the camera stops it.

const FRAME := Vector2(0.5, 0.6)
const FLY_TIME := 0.6
const MIN_DISTANCE := 8.0
const MAX_DISTANCE := 90.0
const ZOOM_RATE := 0.75

var distance := 30.0
var _from := Vector3.ZERO
var _flown := 0.0

func start(camera_rig: CameraRig) -> void:
	var ray := _frame_ray(camera_rig)
	var eye := camera_rig.camera.global_position
	var target := camera_rig.unit.global_position
	var drop := eye.y - target.y
	distance = clampf(drop / -ray.y if ray.y < -0.1 else eye.distance_to(target), MIN_DISTANCE, MAX_DISTANCE)
	_from = camera_rig.user.global_position
	_flown = 0.0

func physics_update(camera_rig: CameraRig, delta: float) -> void:
	var rts := camera_rig.rts_camera
	if camera_rig.forward or camera_rig.backward or camera_rig.left or camera_rig.right or _at_edge(camera_rig):
		camera_rig.stop_following()
		return
	rts.camera_rotate(camera_rig, delta)
	if camera_rig.camera_can_zoom:
		distance = clampf(distance * (1.0 + rts.camera_zoom_direction * ZOOM_RATE * delta), MIN_DISTANCE, MAX_DISTANCE)
		if rts.camera_zoom_slow_down: rts.camera_zoom_direction *= rts.camera_zoom_speed_damp
	var target := camera_rig.unit.global_position - _frame_ray(camera_rig) * distance
	if _flown < FLY_TIME:
		_flown += delta
		target = _from.lerp(target, smoothstep(0.0, FLY_TIME, _flown))
	camera_rig.user.global_position = target

func _frame_ray(camera_rig: CameraRig) -> Vector3:
	return camera_rig.camera.project_ray_normal(camera_rig.get_viewport().get_visible_rect().size * FRAME)

func _at_edge(camera_rig: CameraRig) -> bool:
	var rts := camera_rig.rts_camera
	if not rts.camera_can_auto_pan: return false
	var mouse := camera_rig.get_viewport().get_mouse_position()
	var size := camera_rig.get_viewport().get_visible_rect().size
	var margin := rts.camera_auto_pan_margin
	return mouse.x < margin or mouse.y < margin or mouse.x > size.x - margin or mouse.y > size.y - margin
