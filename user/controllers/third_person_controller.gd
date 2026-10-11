class_name ThirdPersonController extends Controller
# Handle User input while controlling a unit in third person.

var user: User
var camera_rig: CameraRig
var forward := false
var backward := false
var left := false
var right := false
var run := false
var crouch := false
var unit_interact := UnitInteract.new()

func _init(u: User) -> void:
	user = u
	camera_rig = user.camera_rig

func handle_input(event: InputEvent) -> void:
	var camera := camera_rig.third_person_camera
	if event is InputEventMouseMotion:
		camera.look(camera_rig, (event as InputEventMouseMotion).relative)
		_drive()
	elif event.is_action_pressed("MWU"):
		camera.zoom(-1.0)
	elif event.is_action_pressed("MWD"):
		camera.zoom(1.0)
	elif event.is_action_pressed("V"):
		release_inputs()
		if camera_rig.unit: camera_rig.unit.driven = false
		user.leave_unit()
	elif event.is_action_pressed("E"):
		unit_interact.interact(user)
	elif event is InputEventKey and not event.is_echo():
		var down := event.is_pressed()
		if event.is_action("W"): forward = down
		elif event.is_action("S"): backward = down
		elif event.is_action("A"): left = down
		elif event.is_action("D"): right = down
		elif event.is_action("Shift"): run = down
		elif event.is_action("C"): crouch = down
		else: return
		_drive()

# Walking cancels an interaction.
func physics_update(delta: float) -> void:
	var unit := camera_rig.unit
	if unit and unit.command and unit.drive != Vector3.ZERO: unit.take_control()
	unit_interact.physics_update(user, delta)

func release_inputs() -> void:
	forward = false
	backward = false
	left = false
	right = false
	run = false
	crouch = false
	_drive()

# The unit walks where the keys point, relative to the camera. Its first step ends its job and commands.
func _drive() -> void:
	var unit := camera_rig.unit
	if not unit: return
	var input := Vector3(float(right) - float(left), 0.0, float(backward) - float(forward))
	if input == Vector3.ZERO or camera_rig.third_person_camera.flight == ThirdPersonCamera.Flight.OUT:
		unit.drive = Vector3.ZERO
		return
	if not unit.driven:
		unit.take_control()
		unit.driven = true
	var speed := unit.type.crouch_speed if crouch else unit.type.run_speed if run else unit.current_speed
	unit.drive = Basis(Vector3.UP, user.rotation.y) * input.normalized() * speed
