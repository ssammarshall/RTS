class_name ResourceBuilding extends Building

@export var nearby_resources_area: Area3D
@export var nearby_resources_area_collision_shape: CollisionShape3D

var nearby_resource_spawns: Array[ResourceSpawn]

func _ready() -> void:
	super._ready()
	
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

func _on_nearby_resources_area_exited(body: Node3D) -> void:
	body = body.owner
	if body is ResourceSpawn and nearby_resource_spawns.has(body):
		nearby_resource_spawns.erase(body)
