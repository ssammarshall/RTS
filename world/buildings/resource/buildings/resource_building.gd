class_name ResourceBuilding extends Building

enum DepositResult { DEPOSITED, PARTIAL, FULL }

const RESOURCE_RANGE := 50.0 # Spawns of the building's resource within this distance (centre to centre) are gathered from.

signal deposit_blocked(building: ResourceBuilding)
signal capacity_available(building: ResourceBuilding)

var nearby_resource_spawns: Array[ResourceSpawn]

# The job has to exist before the building first enters the tree, where it links its spawns.
func _init() -> void:
	job = Gatherer.new()
	var g := job as Gatherer
	g.anchor = Gatherer.ResourceAnchor.BUILDING
	g.resource_building = self

func _ready() -> void:
	super._ready()
	assert(resource != null)

# Spawns already on the map are linked here; spawns added later link themselves.
func _enter_tree() -> void:
	super._enter_tree()
	if grid_handle < 0: return
	for spawn in spawns_in_range(): add_spawn(spawn)

func _exit_tree() -> void:
	for spawn in nearby_resource_spawns.duplicate(): remove_spawn(spawn)
	super._exit_tree()

# Spawns of this building's resource with some left, within RESOURCE_RANGE.
func spawns_in_range() -> Array[ResourceSpawn]:
	var spawns: Array[ResourceSpawn] = []
	for building in buildings_near(RESOURCE_RANGE):
		var rs := building as ResourceSpawn
		if rs and rs.resource.type == resource.type and rs.resource.amount > 0: spawns.append(rs)
	return spawns

func add_spawn(rs: ResourceSpawn) -> void:
	if rs.resource.type != resource.type or rs.resource.amount <= 0 or nearby_resource_spawns.has(rs): return
	nearby_resource_spawns.append(rs)
	rs.depleted.connect(Callable(remove_spawn))
	if construction_complete: rs.add_nearby_building(self)
	if nearby_resource_spawns.size() == 1: # The only nearby spawn.
		var g := job as Gatherer
		g.resource_spawn = rs

func remove_spawn(rs: ResourceSpawn) -> void:
	if not nearby_resource_spawns.has(rs): return
	nearby_resource_spawns.erase(rs)
	rs.remove_nearby_building(self)
	if rs.depleted.is_connected(Callable(remove_spawn)): rs.depleted.disconnect(Callable(remove_spawn))

	var g := job as Gatherer
	if g.resource_spawn == rs:
		g.resource_spawn = nearby_resource_spawns[0] if not nearby_resource_spawns.is_empty() else null

func start_construction() -> void:
	super.start_construction()
	for spawn in nearby_resource_spawns:
		spawn.add_nearby_building(self)

func deposit_resource(unit: Unit) -> DepositResult:
	if not unit.inventory.resource: return DepositResult.DEPOSITED
	if unit.inventory.resource.type != resource.type: return DepositResult.DEPOSITED

	var space: int = resource_limit - resource.amount
	if space <= 0: return DepositResult.FULL

	var moved: int = min(space, unit.inventory.resource.amount)
	resource.amount += moved
	unit.inventory.resource.amount -= moved

	return DepositResult.PARTIAL if unit.inventory.resource.amount > 0 else DepositResult.DEPOSITED

func consume_resource(amount: int) -> int:
	if amount <= 0 or resource.amount <= 0: return 0
	var was_full: bool = resource.amount >= resource_limit
	var drained: int = min(amount, resource.amount)
	resource.amount -= drained
	if was_full and resource.amount < resource_limit: capacity_available.emit(self)
	return drained

func unit_interaction(unit: Unit) -> void:
	if get_item_type() != ItemData.Type.NONE and not unit.inventory.has_item(get_item_type()):
		unit.inventory.equip(item_data, unit)

	if deposit_resource(unit) != DepositResult.DEPOSITED: deposit_blocked.emit(self)
