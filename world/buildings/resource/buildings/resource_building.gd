class_name ResourceBuilding extends Building

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
	if rs.nearby_resource_buildings.has(self): rs.nearby_resource_buildings.erase(self)
	if rs.depleted.is_connected(Callable(_remove_spawn)): rs.depleted.disconnect(Callable(_remove_spawn))

	var g := job as Gatherer
	if g.resource_spawn == rs:
		g.resource_spawn = nearby_resource_spawns[0] if not nearby_resource_spawns.is_empty() else null

func start_construction() -> void:
	super.start_construction()
	for spawn in nearby_resource_spawns:
		spawn.nearby_resource_buildings.append(self)

func deposit_resource(unit: Unit) -> void:
	if not unit.inventory.resource: return
	elif unit.inventory.resource.type != resource.type: return
	elif resource.amount >= resource_limit: return

	resource.amount += unit.inventory.resource.amount
	unit.inventory.resource.amount = 0

func unit_interaction(unit: Unit) -> void:
	if get_item_type() != ItemData.Type.NONE and not unit.inventory.has_item(get_item_type()):
		unit.inventory.equip(item_data, unit)
	
	deposit_resource(unit)
