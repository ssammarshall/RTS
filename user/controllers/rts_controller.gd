class_name RTSController extends Controller
# Handle User input while in RTS MODE.

enum MODE {
	DEFAULT,
	SELECT,
	BUILD,
	ORDER,
	DRAW # Currently inacessible.
}
var current_mode: MODE = MODE.DEFAULT:
	set(new_mode):
		if current_mode == new_mode: return
		match current_mode:
			MODE.SELECT:
				rts_select.stop_select(user)
			MODE.BUILD:
				rts_build.stop_build(user)
			MODE.ORDER:
				rts_order.stop_order(user)
			MODE.DRAW:
				rts_draw.stop_draw(user)
		
		current_mode = new_mode
		match current_mode:
			MODE.SELECT:
				rts_select.start_select(user)
			MODE.BUILD:
				user.clear_selected()
				rts_build.start_build(user)
			MODE.ORDER:
				rts_order.start_order(user)
			MODE.DRAW:
				rts_draw.start_draw(user)
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

var user: User
var camera_rig: CameraRig
var rts_camera: RTSCamera

var rts_select := RTSSelect.new()
var rts_build := RTSBuild.new()
var rts_order := RTSOrder.new()
var rts_draw := RTSDraw.new() 

func _init(u: User) -> void:
	user = u
	camera_rig = user.camera_rig
	rts_camera = camera_rig.rts_camera
	
	SignalBus.unit_focus.connect(Callable(_on_unit_focus))

func _on_unit_focus(unit: Unit) -> void:
	#camera_rig.follow_unit(unit)
	rts_camera.set_camera_focus_pos(camera_rig, unit.global_position)

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey:
		input_event_key(event)
	
	elif event is InputEventMouseMotion:
		input_event_mouse_motion(event)
	
	elif event is InputEventMouseButton:
		input_event_mouse_button(event)

func input_event_key(event: InputEventKey) -> void:
	if event.is_action_pressed("Shift"):
		user.shift = true
		user.hold_group = true
		return
	elif event.is_action_released("Shift"):
		user.shift = false
		if !user.ctrl: user.hold_group = false
		return
	
	if event.is_action_pressed("Ctrl"):
		user.ctrl = true
		user.hold_group = true
		return
	if event.is_action_released("Ctrl"):
		user.ctrl = false
		if !user.shift: user.hold_group = false
		return
	
	if event.is_action_pressed("Backspace"):
		user.get_selected_group().clear_pathing()
	
	# Camera movement.
	if event.is_action_pressed("W"): camera_rig.forward = true
	elif event.is_action_released("W"): camera_rig.forward = false
	if event.is_action_pressed("S"): camera_rig.backward = true
	elif event.is_action_released("S"): camera_rig.backward = false
	if event.is_action_pressed("A"):
		if user.ctrl:
			rts_select.select_all_units(user) # Select all available units.
			return
		else: camera_rig.left = true
	elif event.is_action_released("A"): camera_rig.left = false
	if event.is_action_pressed("D"): camera_rig.right = true
	elif event.is_action_released("D"): camera_rig.right = false
	
	#if event.is_action_pressed("R"): 
		#if current_mode == MODE.BUILD:
			#camera_rig.mouse_last_position = camera_rig.mouse_current_position
			#camera_rig.camera_can_auto_pan = false
			#Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
			#rts_build.can_rotate_building = true
		#return
	#elif event.is_action_released("R"):
		#if current_mode == MODE.BUILD:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
			#Input.warp_mouse(camera_rig.mouse_last_position)
			#rts_build.can_rotate_building = false
			#camera_rig.camera_can_auto_pan = true
	
	# Keypad camera zoom.
	if event.is_action_pressed("Z"):
		match current_mode:
			MODE.BUILD:
				if user.ctrl:
					SignalBus.building_remove_last.emit()
				else:
					rts_camera.camera_zoom_direction = -1
					rts_camera.camera_zoom_slow_down = false
			_:
				if user.ctrl: return
				rts_camera.camera_zoom_direction = -1
				rts_camera.camera_zoom_slow_down = false
		return
	elif event.is_action_pressed("X"):
		rts_camera.camera_zoom_direction = 1
		rts_camera.camera_zoom_slow_down = false
		return
	elif event.is_action_released("Z") or event.is_action_released("X"):
		rts_camera.camera_zoom_slow_down = true
		return
	
	# Keypad camera rotation.
	if event.is_action_pressed("E"):
		rts_camera.camera_rotation_direction = -1
		rts_camera.camera_rotate_keypad = true
		return
	elif event.is_action_pressed("Q"):
		rts_camera.camera_rotation_direction = 1
		rts_camera.camera_rotate_keypad = true
		return
	elif event.is_action_released("E") or event.is_action_released("Q"):
		rts_camera.camera_rotation_direction = 0
		rts_camera.camera_rotate_keypad = false
		return
	
	if event.is_action_pressed("Enter"):
		return
	
	if event.is_action_pressed("Number"):
		var num:int = int(event.as_text_keycode()) # Get number as int.
		if num == 0: return # Control_group[0] reserved for currently selected group; cannot select group[0].
		if user.ctrl:
			if user.get_selected_group().size() <= 0: return
			user.control_groups[num].add_units(user.get_selected_group().units)
			user.set_control_group(num)
			return
		else:
			for group in user.control_groups:
				if group.group_number == num and group.size() > 0:
					if not user.hold_group: user.clear_selected()
					user.get_selected_group().add_units(group.units)
					user.get_selected_group().select(true)
					return
	
	if event.is_action_pressed("B"):
		match current_mode:
			MODE.BUILD:
				current_mode = MODE.DEFAULT
			_:
				current_mode = MODE.BUILD
		return

func input_event_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.relative.x > 500 or event.relative.x < -500: return # Ignore super fast movements from Input.warp_mouse().
	camera_rig.mouse_offset = Vector2(event.relative.x, event.relative.y)
	return

func input_event_mouse_button(event: InputEventMouseButton) -> void:
	# Mouse wheel camera zoom.
	if event.is_action_pressed("MWU"):
		rts_camera.camera_zoom_direction = -1
		rts_camera.camera_zoom_slow_down = true
		return
	elif event.is_action_pressed("MWD"):
		rts_camera.camera_zoom_direction = 1
		rts_camera.camera_zoom_slow_down = true
		return
	
	# Right-click camera mouse rotation.
	if event.is_action_pressed("MMB"):
		camera_rig.mouse_last_position = camera_rig.mouse_current_position
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		rts_camera.camera_rotate_mouse = true
		return
	elif event.is_action_released("MMB"):
		Input.warp_mouse(camera_rig.mouse_last_position)
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		rts_camera.camera_rotate_mouse = false
		return
	
	# Map interaction.
	if event.is_action_pressed("LMB"):
		var result: Dictionary = Util.mouse_raycast(camera_rig.camera, camera_rig.mouse_current_position)
		
		if result.has("position"):
			user.mouse_global_position = result["position"]
		
		match current_mode:
			MODE.DEFAULT:
				if not user.hold_group: user.clear_selected()
				current_mode = MODE.SELECT
				if result.has("collider"):
					var collision: Object = result["collider"]
					if collision is Building:
						rts_select.select_building(user, collision)
			MODE.SELECT:
				pass
			MODE.BUILD:
				camera_rig.mouse_last_position = camera_rig.mouse_current_position
				rts_build.can_rotate_building = true
				rts_camera.camera_can_auto_pan = false
			MODE.ORDER:
				if not user.hold_group: user.clear_selected()
				current_mode = MODE.SELECT
		return
	elif event.is_action_released("LMB"):
		match current_mode:
			MODE.BUILD:
				if rts_build.place_building(user) and not user.hold_group:
					current_mode = MODE.DEFAULT
					return
				rts_camera.camera_can_auto_pan = true
			MODE.SELECT:
				current_mode = MODE.DEFAULT
		return
	elif event.is_action_pressed("RMB"):
		var result: Dictionary = Util.mouse_raycast(camera_rig.camera, camera_rig.mouse_current_position, 0b11111)
		var pos := Vector3.ZERO
		var collision: Object = null
		if result.has("position"):
			pos = result["position"]
		if result.has("collider"):
			collision = result["collider"]
		
		match current_mode:
			MODE.DEFAULT:
				if user.get_selected_group().units.size() == 0: return
				if pos == Vector3.ZERO: return
				
				if collision is Building:
					rts_order.set_target(user, collision)
					return
				
				var nav_map := user.get_world_3d().get_navigation_map()
				user.mouse_global_position = NavigationServer3D.map_get_closest_point(nav_map, pos)
				current_mode = MODE.ORDER
			MODE.SELECT:
				current_mode = MODE.DEFAULT
			MODE.BUILD:
				rts_build.cancel_building_placement()
			MODE.ORDER: # It never reaches this line?
				pass
		return
	elif event.is_action_released("RMB"):
		match current_mode:
			MODE.ORDER:
				if !user.shift: user.get_selected_group().clear_pathing()
				current_mode = MODE.DEFAULT
		return

func update(delta: float) -> void:
	match current_mode:
		MODE.SELECT:
			# Disable unit selection while cursor is hidden during camera rotation.
			if rts_camera.camera_rotate_mouse:
				current_mode = MODE.DEFAULT
				return
			rts_select.update(user, delta)
		MODE.BUILD:
			rts_build.update(user, delta)
		MODE.ORDER:
			rts_order.update(user, delta)
		MODE.DRAW:
			rts_draw.update(user, delta)
