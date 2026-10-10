class_name TripCommand extends UnitCommand
# A Dormant gatherer's loop made coarsely: one think per trip instead of walking each leg. Each think gathers a load and
# delivers it at once, when the unit would deposit it, so the building gets its stone on time and the pile gives it up a
# leg late. The trip's length was recorded from a trip the unit walked. Between thinks the unit stands where it left the
# building.

var job: Gatherer
var trip_ticks: int # From leaving the building to leaving it again.
var pile_ticks: int # From leaving the building to leaving the pile with a load.
var pile_spot: Vector3 # Where the unit leaves the pile.
var _building_spot: Vector3
var _pile_index: int # The command to the pile in the gatherer's schedule; the one after it goes to the building.
var _type: UnitType
var _start := 0 # Tick the current trip began.
var _settled := false
var _loaded := false # Settled on the leg to the building, carrying a load.

func _init(gatherer: Gatherer, trip: int, to_pile_end: int, from_pile: Vector3) -> void:
	job = gatherer
	trip_ticks = trip
	pile_ticks = to_pile_end
	pile_spot = from_pile
	_pile_index = gatherer.current_command_index

func enter(unit: Unit) -> void:
	_start = Scheduler.tick
	_building_spot = unit.global_position
	_type = unit.type

# Makes the trips that have ended. A trip that doesn't go in full (the pile runs out, the building is full), or a new
# job or type, sends the unit back to walking its legs.
func think(unit: Unit, _delta: float) -> void:
	if not _settled and unit.current_job == job and unit.type == _type and _catch_up(unit): return
	settle(unit)
	if unit.current_job == job: job.start_schedule(unit)
	else: finished.emit()

func next_think(_unit: Unit) -> float:
	return float(_start + trip_ticks - Scheduler.tick) / Engine.physics_ticks_per_second

func exit(unit: Unit) -> void:
	settle(unit)

# Promoted: the unit walks its legs again from where its trip has got to (Unit._unpark then jumps it along the leg).
func unpark(unit: Unit) -> void:
	var walked := settle(unit)
	if unit.current_job != job: finished.emit()
	elif walked < 0: job.start_schedule(unit)
	else:
		job.current_command_index = (_pile_index + 1) % job.schedule.size() if _loaded else _pile_index
		unit.set_command(job.get_current_command())
		unit.path_finder.start_jumping(walked)

# Stops the trips and puts the unit at the start of the leg its trip has got to, with the load it would carry by then.
# Returns how long it has walked that leg, in ticks: -1 if it was already settled or a trip that was due didn't go in full.
func settle(unit: Unit) -> int:
	if _settled or not _catch_up(unit): return -1
	_settled = true
	var walked := Scheduler.tick - _start
	_loaded = walked >= pile_ticks
	if _loaded:
		walked -= pile_ticks
		if is_instance_valid(job.resource_spawn): job.resource_spawn.gather(unit, unit.inventory.resource_limit)
	unit.global_position = pile_spot if _loaded else _building_spot
	Units.moved(unit)
	return walked

# Makes every trip that has ended by now. A trip that doesn't go in full settles the unit where it ended, at the building.
func _catch_up(unit: Unit) -> bool:
	while Scheduler.tick - _start >= trip_ticks:
		_start += trip_ticks
		if not _trip(unit):
			_settled = true
			return false
	return true

# One trip: a load gathered and delivered.
func _trip(unit: Unit) -> bool:
	var spawn := job.resource_spawn
	var building := job.resource_building
	if not is_instance_valid(spawn) or not is_instance_valid(building): return false
	var full := spawn.gather(unit, unit.inventory.resource_limit)
	building.unit_interaction(unit)
	return full and unit.inventory.resource.amount == 0
