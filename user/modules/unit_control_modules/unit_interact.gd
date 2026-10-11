class_name UnitInteract extends UserModule
# The building nearest the controlled unit whose area it can reach, found each tick, and what E does there.

var building: Building
var _found: Array = []

func physics_update(user: User, _delta: float) -> void:
	var rig := user.camera_rig
	var unit := rig.unit
	building = null
	var action := ""
	if unit and rig.third_person_camera.flight == ThirdPersonCamera.Flight.NONE:
		var pos := unit.global_position
		var nearest := INF
		Map.current.building_grid.query_circle(Vector2(pos.x, pos.z), Building.AREA_BOUND + unit.reach, _found)
		for candidate: Building in _found:
			var distance := candidate.area_distance(pos)
			if distance <= unit.reach and distance < nearest and not candidate.interaction_name(unit).is_empty():
				nearest = distance
				building = candidate
		if building: action = "E: %s — %s" % [building.interaction_name(unit), building.title]
	user.third_person_hud.set_prompt(action)

# The AI's own interaction with the building, in place of the unit's job and commands.
func interact(user: User) -> void:
	var unit := user.camera_rig.unit
	if not unit or not building: return
	unit.take_control()
	unit.driven = true
	unit.set_command(InteractCommand.new(building))
