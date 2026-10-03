class_name UnitType extends Resource
# What every unit of a type shares (Type Object / Flyweight). Unit.set_type copies the stats it reads every tick.

enum ControlTier { FULL, LIMITED }
enum Action { SELF_ASSIGN = 1, FIGHT = 2, GIVE_ORDERS = 4, ABILITIES = 8 } # Moving and interacting are open to every unit.

@export var title := ""
@export var portrait: Texture2D
@export var mesh: Mesh # Centred on the unit, which stands half its height above the ground.
@export var material: Material

@export_group("Stats")
@export var speed := 10.0
@export var turn_speed := 10.0
@export var radius := 0.5
@export var height := 2.0
@export var reach := 1.5 # How close the unit has to be to a building's area to interact with it.
@export var carry_limit := 10
@export var run_speed := 8.0 # For the third-person controller.
@export var crouch_speed := 3.0 # For the third-person controller.

@export_group("Control")
@export var allowed_jobs: Array[Script] = []
@export var control_tier: ControlTier = ControlTier.FULL
@export_flags("Self-assign jobs", "Fight", "Give orders", "Abilities") var actions := 15
@export var lowest_detail: Unit.Detail = Unit.Detail.DORMANT # Its units never drop below this simulation detail level.

func allows_job(job: Job) -> bool:
	return allowed_jobs.has(job.get_script())
