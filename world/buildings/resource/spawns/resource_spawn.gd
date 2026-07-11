class_name ResourceSpawn extends Building

var nearby_resource_buildings: Array[ResourceBuilding]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	construction_complete = true # ResourceSpawns do not need to be constructed.
	job = Gatherer.new()
	var g := job as Gatherer
	g.resource_spawn = self

func extract() -> int:
	if resource.amount < 0: return 0
	
	resource.amount -= 1 # eventually update to have more than one type of resource
	return 1

func unit_interaction(unit: Unit) -> void:
	# TEMP
	if not unit.inventory.equipped_item: return
	elif unit.inventory.resource.type != resource.type: # Replace unit's resource with a new resource of the same type as the ResourceSpawn.
		var r := StrategicResource.new()
		r.type = resource.type
		unit.inventory.resource = r
	
	unit.inventory.resource.amount += extract()
