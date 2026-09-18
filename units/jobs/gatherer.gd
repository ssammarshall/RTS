class_name Gatherer extends Job

enum ResourceAnchor { BUILDING, SPAWN }
var anchor := ResourceAnchor.BUILDING

var resource_building: ResourceBuilding
var resource_spawn: ResourceSpawn

func _init() -> void:
	pass

func _update(unit: Unit, _delta: float) -> void:
	if resource_spawn and resource_spawn.resource.amount <= 0: # Resource depleted.
		find_new_resource_spawn(unit)

func find_new_resource_spawn(unit: Unit) -> void:
	resource_spawn = null
	start_schedule(unit)

func start_schedule(unit: Unit) -> void:
	super.start_schedule(unit)
	
	var closest_distance: float = INF
	if resource_building and not resource_spawn:
		var spawns := resource_building.nearby_resource_spawns
		
		for i in spawns.size():
			if spawns[i].resource.amount <= 0: continue # Skip depleted spawns.
			var dist := resource_building.global_position.distance_squared_to(spawns[i].global_position)
			if dist < closest_distance:
				closest_distance = dist
				resource_spawn = spawns[i]
		if not resource_spawn:
			printerr("No ResourceSpawn found")
	elif resource_spawn and not resource_building:
		var buildings := resource_spawn.nearby_resource_buildings
		
		for i in buildings.size():
			var dist := resource_spawn.global_position.distance_squared_to(buildings[i].global_position)
			if dist < closest_distance:
				closest_distance = dist
				resource_building = buildings[i]
		if not resource_building:
			printerr("No ResourceBuilding found")
	
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
