class_name UnitInteract extends UserModule
# The building nearest the controlled unit whose area it can reach, found each tick, and what E and F do there.
# While the AI works the unit's job, the HUD shows the job instead.

var building: Building
var use := ""
var work := ""
var _found: Array = []

func physics_update(user: User, _delta: float) -> void:
	var rig := user.camera_rig
	var unit := rig.unit
	building = null
	use = ""
	work = ""
	var working := unit != null and unit.current_job != null and not unit.driven
	if unit and not working and rig.third_person_camera.flight == ThirdPersonCamera.Flight.NONE:
		var pos := unit.global_position
		var nearest := INF
		Map.current.building_grid.query_circle(Vector2(pos.x, pos.z), Building.AREA_BOUND + unit.reach, _found)
		for candidate: Building in _found:
			var distance := candidate.area_distance(pos)
			if distance > unit.reach or distance >= nearest: continue
			var candidate_use := candidate.interaction_name(unit)
			var candidate_work := _work_name(unit, candidate)
			if candidate_use.is_empty() and candidate_work.is_empty(): continue
			nearest = distance
			building = candidate
			use = candidate_use
			work = candidate_work
	var actions := PackedStringArray()
	if not use.is_empty(): actions.append("E: " + use)
	if not work.is_empty(): actions.append("F: Work here (%s)" % work)
	user.third_person_hud.set_prompt("%s — %s" % [" · ".join(actions), building.title] if building else "")
	user.third_person_hud.set_job("Working: %s — move to take control" % _job_name(unit.current_job) if working else "")

# The AI's own interaction with the building, in place of the unit's job and commands.
func interact(user: User) -> void:
	var unit := user.camera_rig.unit
	if not unit or use.is_empty(): return
	unit.take_control()
	unit.driven = true
	unit.set_command(InteractCommand.new(building))

# The building's job, as an RTS right-click gives it; the AI drives the unit from here.
func self_assign(user: User) -> void:
	var unit := user.camera_rig.unit
	if not unit or work.is_empty(): return
	unit.take_control()
	unit.driven = false
	unit.drive = Vector3.ZERO
	building.assign_worker(unit)

static func _work_name(unit: Unit, candidate: Building) -> String:
	if not candidate.job or not unit.type.allows_job(candidate.job): return ""
	if (unit.type.actions & UnitType.Action.SELF_ASSIGN) == 0: return ""
	return _job_name(candidate.job)

static func _job_name(job: Job) -> String:
	return (job.get_script() as Script).get_global_name()
