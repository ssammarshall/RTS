class_name ResourceBuilding extends Building

@export var nearby_resources_area: Area3D
@export var nearby_resources_area_collision_shape: CollisionShape3D

var nearby_resource_spawns: Array[ResourceSpawn]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	job = Gatherer.new()
	var g := job as Gatherer
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
		nearby_resource_spawns.append(rs)
		if nearby_resource_spawns.size() == 1: # The only nearby spawn.
			var g := job as Gatherer
			g.resource_spawn = rs

func _on_nearby_resources_area_exited(body: Node3D) -> void:
	body = body.owner
	if body is ResourceSpawn and nearby_resource_spawns.has(body):
		nearby_resource_spawns.erase(body)
		if nearby_resource_spawns.size() == 0: # No more nearby spawns.
			var g := job as Gatherer
			g.resource_spawn = null

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
