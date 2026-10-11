class_name ThirdPersonCamera extends CameraModule
# Behind the rig's unit: the pivot sits above its head, the spring arm sets the distance and keeps the camera out of
# the terrain and buildings, and the camera's h_offset puts the unit off to one side. Flying in blends the RTS camera
# (arm 0) into that; flying out blends back to the RTS height and pitch it came from, centred on the unit.

const MIN_FLY_TIME := 0.6
const MAX_FLY_TIME := 1.0
const FAR_FLIGHT := 100.0
const PITCH := -0.3
const MIN_PITCH := -1.3
const MAX_PITCH := 0.4
const SHOULDER := 0.6
const RISE := 0.3
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 12.0
const ZOOM_STEP := 1.0
const ZOOM_RATE := 10.0
const LOOK := 0.0025
const MIN_RTS_HEIGHT := 10.0
const WIND_VOLUME := -8.0
const WIND_SWEEP_FROM := -0.1
const WIND_SWEEP_TO := 0.4

enum Flight { NONE, IN, OUT }

var distance := 5.0
var flight := Flight.NONE
var fly_time := 0.0
var _t := 0.0
var _from_position := Vector3.ZERO
var _from_pitch := 0.0
var _from_arm := 0.0
var _from_shoulder := 0.0
var _rts_height := 0.0
var _rts_pitch := 0.0
var _spot := Vector3.ZERO
var _rise := 0.0
var _wind_pitch := 1.0

func fly_in(camera_rig: CameraRig) -> void:
	_rts_height = camera_rig.user.global_position.y
	_rts_pitch = camera_rig.rotation.x
	_start(camera_rig, Flight.IN)

func fly_out(camera_rig: CameraRig) -> void:
	if flight != Flight.OUT: _start(camera_rig, Flight.OUT)

func look(camera_rig: CameraRig, relative: Vector2) -> void:
	if flight != Flight.NONE: return
	var turn := LOOK * camera_rig.user.mouse_sens
	camera_rig.user.rotation.y -= relative.x * turn
	camera_rig.rotation.x = clampf(camera_rig.rotation.x - relative.y * turn, MIN_PITCH, MAX_PITCH)

func zoom(direction: float) -> void:
	distance = clampf(distance + direction * ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)

func physics_update(camera_rig: CameraRig, delta: float) -> void:
	_track(camera_rig)
	var pivot := _spot + Vector3.UP * _rise
	var arm := camera_rig.spring_arm
	if flight == Flight.NONE:
		camera_rig.user.global_position = pivot
		arm.spring_length = lerpf(arm.spring_length, distance, minf(ZOOM_RATE * delta, 1.0))
		return
	_t += delta
	_sweep_wind(camera_rig)
	var into := flight == Flight.IN
	var blend := smoothstep(0.0, fly_time, _t)
	camera_rig.user.global_position = _from_position.lerp(pivot if into else _rts_spot(camera_rig), blend)
	camera_rig.rotation.x = lerpf(_from_pitch, PITCH if into else _rts_pitch, blend)
	arm.spring_length = lerpf(_from_arm, distance if into else 0.0, blend)
	camera_rig.camera.h_offset = lerpf(_from_shoulder, SHOULDER if into else 0.0, blend)
	if _t < fly_time: return
	flight = Flight.NONE
	camera_rig.wind.stop()
	if not into: camera_rig.land()

func _start(camera_rig: CameraRig, kind: Flight) -> void:
	flight = kind
	_t = 0.0
	_from_position = camera_rig.user.global_position
	_from_pitch = camera_rig.rotation.x
	_from_arm = camera_rig.spring_arm.spring_length
	_from_shoulder = camera_rig.camera.h_offset
	_track(camera_rig)
	var to := _spot + Vector3.UP * _rise if kind == Flight.IN else _rts_spot(camera_rig)
	fly_time = lerpf(MIN_FLY_TIME, MAX_FLY_TIME, clampf(_from_position.distance_to(to) / FAR_FLIGHT, 0.0, 1.0))
	var wind := camera_rig.wind
	if not wind.stream: return
	_wind_pitch = wind.stream.get_length() / fly_time
	_sweep_wind(camera_rig)
	wind.volume_db = WIND_VOLUME
	wind.play()

# Up flying in, down flying out, around the pitch that fits the sound to the flight, divided by the sweep's average
# so the sound still ends with the flight.
func _sweep_wind(camera_rig: CameraRig) -> void:
	var side := 1.0 if flight == Flight.IN else -1.0
	var bend := side * lerpf(WIND_SWEEP_FROM, WIND_SWEEP_TO, minf(_t / fly_time, 1.0))
	var mean := side * (WIND_SWEEP_FROM + WIND_SWEEP_TO) * 0.5
	camera_rig.wind.pitch_scale = _wind_pitch * (1.0 + bend) / (1.0 + mean)

# Where the unit is, or was when it left.
func _track(camera_rig: CameraRig) -> void:
	var unit := camera_rig.unit
	if not unit: return
	_spot = unit.global_position
	_rise = unit.height * 0.5 + RISE

# The RTS camera at the height and pitch it flew in from, looking at the unit's spot.
func _rts_spot(camera_rig: CameraRig) -> Vector3:
	var height := maxf(_rts_height - _spot.y, MIN_RTS_HEIGHT)
	var back := Basis(Vector3.UP, camera_rig.user.rotation.y) * Vector3.BACK
	return _spot + Vector3.UP * height + back * (height / tan(maxf(-_rts_pitch, 0.1)))
