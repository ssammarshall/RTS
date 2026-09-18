class_name Gatherer extends Job

enum ResourceAnchor { BUILDING, SPAWN }
var anchor := ResourceAnchor.BUILDING

var resource_building: ResourceBuilding
var resource_spawn: ResourceSpawn

var _unit: Unit
var _connected_building: Building
var _connected_spawn: ResourceSpawn
var _waiting := false

func _init() -> void:
	pass

func _update(unit: Unit, _delta: float) -> void:
	if _waiting: return
	if resource_spawn and resource_spawn.resource.amount <= 0:
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
	_waiting = false

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

	_connect(unit)
	unit.set_command(get_current_command())

func set_first_command(command: InteractCommand) -> void:
	schedule.clear()
	if command.target is ResourceBuilding: # Equip item first, then gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_spawn))
	else: # Go straight to the gather resource.
		schedule.append(command)
		schedule.append(InteractCommand.new(resource_building))

func _connect(unit: Unit) -> void:
	_disconnect()
	_unit = unit
	if not resource_building or not resource_spawn: return

	if anchor == ResourceAnchor.BUILDING:
		resource_building.removed.connect(_on_anchor_removed)
		resource_spawn.removed.connect(_on_derived_removed)
	else:
		resource_spawn.removed.connect(_on_anchor_removed)
		resource_building.removed.connect(_on_derived_removed)
		resource_spawn.nearby_buildings_changed.connect(_on_nearby_buildings_changed)

	resource_building.capacity_available.connect(_on_capacity_available)
	resource_building.deposit_blocked.connect(_on_deposit_blocked)

	_connected_building = resource_building
	_connected_spawn = resource_spawn

func _disconnect() -> void:
	if _connected_building:
		if _connected_building.removed.is_connected(_on_anchor_removed): _connected_building.removed.disconnect(_on_anchor_removed)
		if _connected_building.removed.is_connected(_on_derived_removed): _connected_building.removed.disconnect(_on_derived_removed)
		if _connected_building is ResourceBuilding:
			var rb := _connected_building as ResourceBuilding
			if rb.capacity_available.is_connected(_on_capacity_available): rb.capacity_available.disconnect(_on_capacity_available)
			if rb.deposit_blocked.is_connected(_on_deposit_blocked): rb.deposit_blocked.disconnect(_on_deposit_blocked)
	if _connected_spawn:
		if _connected_spawn.removed.is_connected(_on_anchor_removed): _connected_spawn.removed.disconnect(_on_anchor_removed)
		if _connected_spawn.removed.is_connected(_on_derived_removed): _connected_spawn.removed.disconnect(_on_derived_removed)
		if _connected_spawn.nearby_buildings_changed.is_connected(_on_nearby_buildings_changed): _connected_spawn.nearby_buildings_changed.disconnect(_on_nearby_buildings_changed)
	_connected_building = null
	_connected_spawn = null

func _on_anchor_removed(_building: Building) -> void:
	if _unit: _unit.set_job(null) # Anchor is fixed intent; without it the job cannot continue.

func _on_derived_removed(_building: Building) -> void:
	if _unit: reevaluate(_unit) # Find the derived ResourceAnchor or cancel if none remain.

func _on_nearby_buildings_changed(_spawn: ResourceSpawn) -> void:
	if _unit: reevaluate(_unit) # Optimize to the closest building; only connected for spawn anchors.

func _on_deposit_blocked(_building: ResourceBuilding) -> void:
	if not _unit: return
	if not _unit.inventory.resource or _unit.inventory.resource.amount <= 0: return

	var target := find_building_with_space()
	if not target:
		_waiting = true
		_unit.set_command(WaitForCapacityCommand.new())
		return

	resource_building = target
	if anchor == ResourceAnchor.BUILDING: resource_spawn = null
	start_schedule(_unit)

func find_building_with_space() -> ResourceBuilding:
	if not resource_spawn: return null
	var closest: ResourceBuilding = null
	var closest_distance: float = INF
	for building in resource_spawn.nearby_resource_buildings:
		if building.resource.amount >= building.resource_limit: continue
		var dist := resource_spawn.global_position.distance_squared_to(building.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest = building
	return closest

func _on_capacity_available(_building: ResourceBuilding) -> void:
	if _waiting and _unit: start_schedule(_unit)

func teardown(_unit_param: Unit) -> void:
	_disconnect()
	_unit = null

func copy() -> Gatherer:
	var gatherer := Gatherer.new()
	gatherer.anchor = anchor
	gatherer.resource_building = resource_building
	gatherer.resource_spawn = resource_spawn
	return gatherer
