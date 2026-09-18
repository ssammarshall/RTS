class_name Gatherer extends Job

enum ResourceAnchor { BUILDING, SPAWN }
var anchor := ResourceAnchor.BUILDING

var resource_building: ResourceBuilding
var resource_spawn: ResourceSpawn

func _init() -> void:
	pass

func _update(unit: Unit, _delta: float) -> void:
	if resource_spawn and resource_spawn.resource.amount <= 0: # Resource depleted.
		reevaluate(unit)

func reevaluate(unit: Unit) -> void:
	if not anchor_valid():
		printerr("Anchor invalid. Cancel job.")
		unit.set_job(null)
		return

	var previous_building := resource_building
	var previous_spawn := resource_spawn

	if anchor == ResourceAnchor.BUILDING: resource_spawn = null
	else: resource_building = null

	select_derived()

	if resource_building == previous_building and resource_spawn == previous_spawn:
		return

	start_schedule(unit)

func anchor_valid() -> bool:
	if anchor == ResourceAnchor.BUILDING:
		return resource_building != null
	return resource_spawn != null and resource_spawn.resource.amount > 0 # Spawn anchor must still have resources.

# Select the closest resource building or spawn based on the anchor type.
func select_derived() -> void:
	var closest_distance: float = INF
	if resource_building and not resource_spawn:
		for spawn in resource_building.nearby_resource_spawns:
			if spawn.resource.amount <= 0: continue # Skip depleted spawns.
			var dist := resource_building.global_position.distance_squared_to(spawn.global_position)
			if dist < closest_distance:
				closest_distance = dist
				resource_spawn = spawn
	elif resource_spawn and not resource_building:
		for building in resource_spawn.nearby_resource_buildings:
			var dist := resource_spawn.global_position.distance_squared_to(building.global_position)
			if dist < closest_distance:
				closest_distance = dist
				resource_building = building

func start_schedule(unit: Unit) -> void:
	super.start_schedule(unit)

	select_derived()

	if not resource_building or not resource_spawn:
		printerr("Cancel job. ", resource_building, resource_spawn)
		unit.set_job(null)
		
		# Go to either the ResourceBuilding or ResourceSpawn if set.
		if resource_building: unit.set_command(MoveCommand.new(resource_building.global_position))
		elif resource_spawn: unit.set_command(MoveCommand.new(resource_spawn.global_position))
		return
	
	if resource_spawn.get_item_type() == ItemData.Type.NONE: # No item needed to gather resource.
		unit.inventory.unequip(unit) # Unequip any item the unit may have equipped. TODO: Check if the item can be saved before unequipping.
		set_first_command(InteractCommand.new(resource_spawn))
	elif not unit.inventory.has_item(resource_spawn.get_item_type()): # Unit does not have required item to gather resource. Go equip the item.
		if resource_building.get_item_type() != resource_spawn.get_item_type():
			printerr("ResourceBuilding and ResourceSpawn have different required item types. Cancel job. ", resource_building.get_item_type(), resource_spawn.get_item_type())
			unit.set_job(null)
			return
		set_first_command(InteractCommand.new(resource_building))
	else: # Go to gather resource.
		set_first_command(InteractCommand.new(resource_spawn))
	
	unit.set_command(get_current_command())

func set_first_command(command: InteractCommand) -> void:
	schedule.clear()
	if command.target is ResourceBuilding: # Equip item first, then gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_spawn))
	else: # Go straight to the gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_building))

func copy() -> Gatherer:
	var gatherer := Gatherer.new()
	gatherer.anchor = anchor
	gatherer.resource_building = resource_building
	gatherer.resource_spawn = resource_spawn
	return gatherer
