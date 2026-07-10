class_name ResourceSpawn extends Building

var nearby_resource_buildings: Array[ResourceBuilding]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	construction_complete = true # ResourceSpawns do not need to be constructed.
	job = Gatherer.new()
	job.resource_spawn = self

func extract() -> int:
	if resource.amount < 0: return 0
	
	resource.amount -= 1 # eventually update to have more than one type of resource
	return 1

func unit_interaction(unit: Unit) -> void:
	# TEMP
	if not unit.equipped_item: return
	elif unit.resource.type != resource.type: return
	
	unit.resource.amount += extract()
