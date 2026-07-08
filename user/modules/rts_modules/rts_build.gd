class_name RTSBuild extends UserModule

var building: Building
var overlapping_bodies: Array[Node3D]
var can_place_building := false
var can_rotate_building := false
var was_placement_cancelled := false

func _init() -> void:
	SignalBus.start_building_placement.connect(Callable(_on_start_building_placement))

func _on_start_building_placement(user: User, bldg: Building) -> void:
	building = bldg
	
	building.building_area.area_entered.connect(Callable(_on_area_entered))
	building.building_area.area_exited.connect(Callable(_on_area_exited))
	
	user.get_tree().get_root().add_child(building)
	building.display_building_preview(true)
	building.set_building_collision_layer(1, false) # Disable collision when trying to place Building.

func start_build(_user: User) -> void:
	can_place_building = false
	can_rotate_building = false
	
	SignalBus.set_build_mode.emit(true)

func stop_build(_user: User) -> void:
	if building:
		building.queue_free()
	SignalBus.set_build_mode.emit(false)

func update(user: User, _delta: float) -> void:
	if not building: return
	
	can_place_building = check_building_placement(user)
	
	if can_rotate_building:
		rotate_building(user)
		return
	
	var pos: Vector3 = Util.mouse_raycast_3d_position(user.camera_rig.camera, user.camera_rig.mouse_current_position, 0b10000)
	if pos == Vector3.ZERO: return
	
	building.global_position = pos

# Add body to overlapping_bodies array.
func _on_area_entered(body: Node3D) -> void:
	if not building: return
	if body != building:
		overlapping_bodies.append(body)

# Remove body in overlapping_bodies array.
func _on_area_exited(body: Node3D) -> void:
	if overlapping_bodies.has(body):
		overlapping_bodies.erase(body)

func cancel_building_placement() -> void:
	if can_rotate_building:
		was_placement_cancelled = true
		can_rotate_building = false
	elif building:
		building.queue_free()
		building = null

func check_building_placement(user: User) -> bool:
	if not building: return false
	
	building.set_preview_color(Global.RED_TRANSPARENT)
	
	if overlapping_bodies.size() > 0: return false
	
	var area_collision := building.building_area_collision_shape
	var size: Vector3 = area_collision.get_shape().size * 0.5
	
	size.y -= 1
	var area_corners: Array[Vector3] = [
		building.building_area.global_position + Vector3(size.x, -size.y, size.z),
		building.building_area.global_position + Vector3(size.x, -size.y, -size.z),
		building.building_area.global_position + Vector3(-size.x, -size.y, size.z),
		building.building_area.global_position + Vector3(-size.x, -size.y, -size.z)
	]
	var corner_distances: Array[float] = []
	
	for i in area_corners.size():
		var from := area_corners[i]
		var to := from + Vector3(0, -20, 0)
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		ray_query.collision_mask = 0b11001
		
		var camera_rig: CameraRig = user.camera_rig
		var camera: Camera3D = camera_rig.camera
		
		var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().get_direct_space_state()
		var result: Dictionary = space_state.intersect_ray(ray_query)
		
		if result:
			corner_distances.append(from.y - result.position.y)
		else:
			return false
	
	for i in corner_distances.size():
		if corner_distances[i] > 2.0:
			return false
	
	if building is ProductionBuilding:
		var pb := building as ProductionBuilding
		if pb.nearby_resource_spawns.size() == 0:
			pb.set_preview_color(Global.YELLOW_TRANSPARENT)
		else:
			building.set_preview_color(Global.GREEN_TRANSPARENT)
	else: building.set_preview_color(Global.GREEN_TRANSPARENT)
	
	return true

func place_building(user: User) -> bool:
	if not building: return false
	if not can_place_building:
		can_rotate_building = false
		was_placement_cancelled = false
		return false
	if was_placement_cancelled:
		was_placement_cancelled = false
		return false
	
	building.display_building_preview(true) # Keep Building preview active.
	building.set_building_collision_layer(4, true) # Allow Units to pass thru Building but keep Building selectable by User.
	
	SignalBus.building_placed.emit(building)
	
	if user.hold_group:
		var next_building: Building = building.duplicate() as Building
		building = next_building
		user.get_tree().get_root().add_child(building)
	else:
		building = null
	
	can_rotate_building = false # Prevent next building from automatically starting rotation.
	
	return true

func rotate_building(user: User) -> void:
	if not building: return
	
	var camera_rig: CameraRig = user.camera_rig
	
	var new_rotation := building.rotation_degrees.y + camera_rig.mouse_offset.x
	new_rotation = wrapf(new_rotation, 0, 360)
	building.rotation_degrees.y = new_rotation
	
	camera_rig.mouse_offset = Vector2.ZERO
	
	Util.check_mouse_margins(camera_rig.get_viewport(), camera_rig.mouse_current_position)
