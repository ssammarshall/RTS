class_name RTSSelect extends UserModule
# Handles User selection while in RTS mode.

# CONSTANTS.
const MIN_DRAG: float = 128

func start_select(user: User) -> void:
	user.camera_rig.mouse_last_position = user.camera_rig.mouse_current_position
	user.rect.position = user.camera_rig.mouse_last_position
	user.dragbox.position = user.rect.position

func stop_select(user: User) -> void:
	user.rect.size = Vector2.ZERO
	user.dragbox.visible = false

func update(user: User, _delta: float) -> void:
	user.rect.size = user.camera_rig.mouse_current_position - user.rect.position
	if !user.dragbox.visible:
		if user.rect.size.length_squared() > MIN_DRAG:
			user.dragbox.visible = true
	# Allow dragbox to be drawn in any direction.
	user.dragbox.size = abs(user.rect.size)
	if user.rect.size.x < 0:
		user.dragbox.scale.x = -1
	else:
		user.dragbox.scale.x = 1
	if user.rect.size.y < 0:
		user.dragbox.scale.y = -1
	else:
		user.dragbox.scale.y = 1
	
	cast_unit_selection(user, user.rect)

# Check selectable Units via dragbox and mouse_raycast_collider.
func cast_unit_selection(user: User, dragbox: Rect2) -> void:
	for unit in user.available_units:
		# Ignore if already selected.
		if !user.control_groups[0].units.has(unit):
			# Check if unit is inside dragbox.
			if dragbox.abs().has_point(user.camera_rig.camera.unproject_position(unit.global_position)):
				select_unit(user, unit)
				break
	# Check if mouse is hovering unit.
	var collision: Object = Util.mouse_raycast_collider(user.camera_rig.camera,user.camera_rig.mouse_current_position)
	if collision is Unit:
		if user.available_units.has(collision):select_unit(user, collision)

# Highlight Unit and add to control_groups[0].
func select_unit(user: User, unit: Unit) -> void:
	if user.control_groups[0].units.has(unit):return
	else:user.control_groups[0].add_unit(unit)
	unit.select(true)

# Unhighlight Unit and remove from control_groups[0].
func deselect_unit(user: User, unit: Unit) -> void:
	if !user.control_groups[0].units.has(unit):return
	else:user.control_groups[0].remove_unit(unit)
	unit.select(false)

# Highlight and add all Units to control_groups[0].
func select_all_units(user: User) -> void:
	for unit in user.available_units:
		if !user.control_groups[0].has(unit):user.control_groups[0].add_unit(unit)
		unit.select(true)

# Highlight Building and reveal its information.
func select_building(_user: User, building: Building) -> void:
	SignalBus.building_selected.emit(building)
