class_name ResourceBuilding extends Building

enum DepositResult { DEPOSITED, PARTIAL, FULL }

signal deposit_blocked(building: ResourceBuilding)
signal capacity_available(building: ResourceBuilding)

@export var nearby_resources_area: Area3D
@export var nearby_resources_area_collision_shape: CollisionShape3D

var nearby_resource_spawns: Array[ResourceSpawn]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	job = Gatherer.new()
	var g := job as Gatherer
	g.anchor = Gatherer.ResourceAnchor.BUILDING
	g.resource_building = self

	nearby_resources_area.set_collision_layer_value(Global.COLLISION_LAYER.WORLD, false)
	nearby_resources_area.set_collision_mask_value(Global.COLLISION_LAYER.WORLD, false)
	nearby_resources_area.set_collision_mask_value(Global.COLLISION_LAYER.BUILDING, true)
	
	nearby_resources_area.area_entered.connect(Callable(_on_nearby_resources_area_entered))
	nearby_resources_area.area_exited.connect(Callable(_on_nearby_resources_area_exited))


func _on_nearby_resources_area_entered(body: Node3D) -> void:
	body = body.owner
	if body == self: return
	if body is ResourceSpawn:
		var rs := body as ResourceSpawn
		if rs.resource.type != self.resource.type: return
		if rs.resource.amount <= 0: return
		nearby_resource_spawns.append(rs)
		rs.depleted.connect(Callable(_remove_spawn))
		if nearby_resource_spawns.size() == 1: # The only nearby spawn.
			var g := job as Gatherer
			g.resource_spawn = rs

func _on_nearby_resources_area_exited(body: Node3D) -> void:
	body = body.owner
	if body is ResourceSpawn:
		_remove_spawn(body)

func _remove_spawn(rs: ResourceSpawn) -> void:
	if not nearby_resource_spawns.has(rs): return
	nearby_resource_spawns.erase(rs)
	rs.remove_nearby_building(self)
	if rs.depleted.is_connected(Callable(_remove_spawn)): rs.depleted.disconnect(Callable(_remove_spawn))

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
