class_name ThirdPersonController extends Controller
# Handle User input while controlling a unit in third person.

var user: User
var camera_rig: CameraRig

func _init(u: User) -> void:
	user = u
	camera_rig = user.camera_rig

func handle_input(event: InputEvent) -> void:
	var camera := camera_rig.third_person_camera
	if event is InputEventMouseMotion:
		camera.look(camera_rig, (event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("MWU"):
		camera.zoom(-1.0)
	elif event.is_action_pressed("MWD"):
		camera.zoom(1.0)
	elif event.is_action_pressed("V"):
		user.leave_unit()
