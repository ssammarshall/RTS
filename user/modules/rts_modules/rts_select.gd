class_name RTSSelect extends UserModule
# Handles User selection while in RTS mode.

# CONSTANTS.
const MIN_DRAG: float = 128

var _boxed := {} # Unit this drag selected -> the last frame it was in the box or under the mouse. Units selected before the drag stay.
var _frame := 0

func start_select(user: User) -> void:
	user.camera_rig.mouse_last_position = user.camera_rig.mouse_current_position
	user.rect.position = user.camera_rig.mouse_last_position
	user.dragbox.position = user.rect.position
	_boxed.clear()

func stop_select(user: User) -> void:
	user.rect.size = Vector2.ZERO
	user.dragbox.visible = false
	_boxed.clear()

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

# Selects the user's units in the dragbox and the one under the mouse. Once the box is dragged out, the ones this drag
# selected that are in neither are deselected; until then it's a click, and they stay. Units on screen are never
# Dormant, so only acting units are checked.
func cast_unit_selection(user: User, dragbox: Rect2) -> void:
	var camera := user.camera_rig.camera
	var dragged := dragbox.size.length_squared() > MIN_DRAG
	_frame += 1
	var marked := 0
	if dragged:
		var box := dragbox.abs()
		var screen := camera.get_viewport().get_visible_rect().size
		var left := box.position.x / screen.x * 2.0 - 1.0
		var right := box.end.x / screen.x * 2.0 - 1.0
		var top := 1.0 - box.position.y / screen.y * 2.0
		var bottom := 1.0 - box.end.y / screen.y * 2.0
		var to_clip := camera.get_camera_projection() * Projection(camera.get_camera_transform().affine_inverse())
		for unit in Units.acting:
			var pos := unit.global_position
			var clip := to_clip * Vector4(pos.x, pos.y, pos.z, 1.0)
			var w := clip.w
			if w <= 0.0 or clip.x < left * w or clip.x > right * w or clip.y > top * w or clip.y < bottom * w: continue
			if _boxed.has(unit): _boxed[unit] = _frame
			elif not _take(user, unit): continue
			marked += 1
	var hovered := Units.pick(camera, user.camera_rig.mouse_current_position)
	if hovered and _boxed.get(hovered, -1) != _frame:
		if _boxed.has(hovered):
			_boxed[hovered] = _frame
			marked += 1
		elif _take(user, hovered): marked += 1
	if not dragged or marked == _boxed.size(): return
	for unit: Unit in _boxed.keys():
		if _boxed[unit] == _frame: continue
		deselect_unit(user, unit)
		_boxed.erase(unit)

func _take(user: User, unit: Unit) -> bool:
	if user.get_selected_group().has(unit) or not user.owns(unit): return false
	select_unit(user, unit)
	_boxed[unit] = _frame
	return true

# Highlight Unit and add to control_groups[0].
func select_unit(user: User, unit: Unit) -> void:
	if not user.owns(unit) or user.get_selected_group().has(unit): return
	user.get_selected_group().add_unit(unit)
	unit.select(true)

# Unhighlight Unit and remove from control_groups[0].
func deselect_unit(user: User, unit: Unit) -> void:
	if not user.get_selected_group().has(unit): return
	user.get_selected_group().remove_unit(unit)
	unit.select(false)

# Highlight and add all Units to control_groups[0].
func select_all_units(user: User) -> void:
	for unit in user.available_units: select_unit(user, unit)

# Highlight Building and reveal its information.
func select_building(_user: User, building: Building) -> void:
	SignalBus.building_selected.emit(building)
