class_name ResourceSpawn extends Building

signal depleted(spawn: ResourceSpawn)

var nearby_resource_buildings: Array[ResourceBuilding]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	construction_complete = true # ResourceSpawns do not need to be constructed.
	job = Gatherer.new()
	var g := job as Gatherer
	g.anchor = Gatherer.ResourceAnchor.SPAWN
	g.resource_spawn = self

func extract() -> int:
	if resource.amount <= 0: return 0
	
	resource.amount -= 1 # eventually update to have more than one type of resource
	if resource.amount <= 0: depleted.emit(self) # Fires once, on the crossing to empty.
	return 1

func unit_interaction(unit: Unit) -> void:
	if get_item_type() != ItemData.Type.NONE and not unit.inventory.has_item(get_item_type()): return
	if resource.amount <= 0: return

	var can_extract := unit.inventory.use_item(unit)
	if can_extract: unit.inventory.resource.amount += extract()
