class_name ResourceSpawn extends Building

signal depleted(spawn: ResourceSpawn)
signal nearby_buildings_changed(spawn: ResourceSpawn)

var nearby_resource_buildings: Array[ResourceBuilding]

func _ready() -> void:
	super._ready()
	assert(resource != null)
	
	construction_complete = true # ResourceSpawns do not need to be constructed.
	job = Gatherer.new()
	var g := job as Gatherer
	g.anchor = Gatherer.ResourceAnchor.SPAWN
	g.resource_spawn = self

func add_nearby_building(building: ResourceBuilding) -> void:
	if nearby_resource_buildings.has(building): return
	nearby_resource_buildings.append(building)
	nearby_buildings_changed.emit(self)

func remove_nearby_building(building: ResourceBuilding) -> void:
	if not nearby_resource_buildings.has(building): return
	nearby_resource_buildings.erase(building)
	nearby_buildings_changed.emit(self)

func extract(amount := 1) -> int:
	var extracted := clampi(resource.amount, 0, amount)
	if extracted <= 0: return 0
	resource.amount -= extracted # eventually update to have more than one type of resource
	if resource.amount <= 0: depleted.emit(self) # Fires once, on the crossing to empty.
	return extracted

func unit_interaction(unit: Unit) -> void:
	gather(unit, 1)

# Up to `times` gathering interactions, each taking one resource with one use of the tool. False once the unit has to
# stop: it lacks the tool, its load is full or the spawn is empty (the interaction after that finishes the command).
func gather(unit: Unit, times: int) -> bool:
	var inventory := unit.inventory
	var tool_needed := get_item_type() != ItemData.Type.NONE
	if tool_needed and not inventory.has_item(get_item_type()): return false
	inventory.swap_resource_type(resource.type)
	var n := mini(times, mini(inventory.resource_limit - inventory.resource.amount, resource.amount))
	var used := inventory.use_item(unit, n) if n > 0 else 0
	inventory.resource.amount += extract(used)
	return n == times and (used == n or not tool_needed)
