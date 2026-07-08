class_name Unit extends CharacterBody3D

# Nodes.
@onready var interaction_area: Area3D = $Area3D

# Components.
@export var selectable: SelectableObject
@export var path_finder: PathFinder
@export var flock_agent: FlockAgent

# Unit Roles.
@export var unit_roles: Array[UnitRole]
var active_role: UnitRole

# Selection.
signal selected(value: bool)
@export var portrait: Texture2D
var group_num: int = -1

# Allow Commands to be given to unit.
var command: UnitCommand
var command_queue: Array[UnitCommand]

var nearby_bodies: Array[Node3D]

# Pathing used with PathFinder.
var pathing: bool = false

# Movement.
@export_group("Stats")
@export var base_speed: float = 5.0
@export var turn_speed: float = 10.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 3.0
@export var jump_height: float = 3.0
@export var current_speed: float= 10

# Inventory                                           MOVE TO SEPERATE CLASS
var resource := StrategicResource.new()
var equipped_item: Item

var height: float = 2.0

func _ready() -> void:
	select(false)
	
	# Assign active role if not already assigned.
	if not active_role and unit_roles.size() > 0: active_role = unit_roles[0]
	if active_role: active_role.start_schedule()
	
	# TEST
	resource.type = StrategicResource.Type.Stone
	resource.amount = 0
	
	interaction_area.area_entered.connect(Callable(_on_interaction_area_entered))
	interaction_area.area_exited.connect(Callable(_on_interaction_area_exited))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor(): velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity")
	
	# Add match statement for when is player controlled/AI
	if pathing: path_finder.physics_update(delta)
	#flock_agent.physics_update(delta)
	
	if active_role: active_role._update(self, delta)
	if command: command.execute(self, delta)
	
	move_and_slide()

func _on_command_finished() -> void:
	set_command(null)

# Keep track of all nearby Node3Ds in interaction_area and append to nearby_bodies array.
func _on_interaction_area_entered(body: Node3D) -> void:
	var node: Node3D = body.get_parent()
	nearby_bodies.append(node)

# Remove all Node3Ds from nearby_bodies array that leave interaction_area.
func _on_interaction_area_exited(body: Node3D) -> void:
	var node: Node3D = body.get_parent()
	if nearby_bodies.has(node):
		nearby_bodies.erase(node)

# Select Unit and emit selected signal.
func select(value: bool) -> void:
	selectable.is_selected = value
	selected.emit(value)

# Create UnitCard with information for this Unit and given index.
func create_unit_card(index: int) -> UnitCard:
	var unit_card := Global.UNIT_CARD.instantiate() as UnitCard
	unit_card.setup(index, self)
	
	return unit_card

func set_group_num(num: int) -> void:
	group_num = num

func clear_commands() -> void:
	command_queue.clear()
	set_command(null)

func set_command(cmnd: UnitCommand) -> void:
	if command:
		command.exit(self)
		command.finished.disconnect(Callable(_on_command_finished))
	command = cmnd
	if command:
		command.finished.connect(Callable(_on_command_finished))
		command.enter(self)
	elif command_queue.size() > 0: set_command(command_queue.pop_front())
