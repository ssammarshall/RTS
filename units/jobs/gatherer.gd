class_name Gatherer extends Job

var resource_building: ResourceBuilding
var resource_spawn: ResourceSpawn

func _init() -> void:
	pass

func start_schedule(unit: Unit) -> void:
	super.start_schedule(unit)
	
	var distance: float = INF
	if resource_building and not resource_spawn:
		var spawns := resource_building.nearby_resource_spawns
		
		for i in spawns.size():
			if resource_building.global_position.distance_squared_to(spawns[i].global_position) < distance:
				resource_spawn = spawns[i]
		if not resource_spawn:
			printerr("No ResourceSpawn found")
	elif resource_spawn and not resource_building:
		var buildings := resource_spawn.nearby_resource_buildings
		
		for i in buildings.size():
			if resource_spawn.global_position.distance_squared_to(buildings[i].global_position) < distance:
				resource_building = buildings[i]
		if not resource_building:
			printerr("No ResourceBuilding found")
	
	if not resource_building or not resource_spawn:
		printerr("Cancel job. ", resource_building, resource_spawn)
		unit.set_job(null)
		return
	
	if not resource_building.item: # No item needed to gather resource.
		unit.equipped_item = null
		set_first_command(InteractCommand.new(resource_spawn))
	elif unit.equipped_item != resource_building.item: # Unit does not have required item to gather resource. Go equip the item.
		set_first_command(InteractCommand.new(resource_building))
	else: # Go to gather resource.
		set_first_command(InteractCommand.new(resource_spawn))
	
	unit.set_command(get_current_command())

func set_first_command(command: InteractCommand) -> void:
	if command.target is ResourceBuilding: # Equip item first, then gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_spawn))
	else: # Go straight to the gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_building))

func copy() -> Gatherer:
	var gatherer := Gatherer.new()
	gatherer.resource_building = resource_building
	gatherer.resource_spawn = resource_spawn
	return gatherer
