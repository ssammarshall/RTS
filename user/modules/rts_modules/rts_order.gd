class_name RTSOrder extends UserModule

# Space between Units.
const PADDING: float = 1.5

# Unit formation.
var base: Node3D # Where the formation starts.
var unit_decals: Array[Decal]
var formation_box: MeshInstance3D

func start_order(user: User) -> void:
	base = Node3D.new()
	user.get_tree().get_root().add_child(base)
	
	base.global_position = user.mouse_global_position
	formation_box = MeshInstance3D.new()
	formation_box.mesh = BoxMesh.new()
	formation_box.visible = true
	base.add_child(formation_box)
	base.visible = false
	
	for x in user.get_selected_group().size():
		var decal := Decal.new()
		decal.size = Vector3(0.7,2,0.7)
		decal.texture_albedo = preload("uid://w1ixg5bhlopc")
		unit_decals.append(decal)
		base.add_child(decal)

func stop_order(user: User) -> void:
	if !base or !unit_decals: return
	for i in user.get_selected_group().size():
		var unit: Unit = user.get_selected_group().units[i]
		unit.set_command(MoveCommand.new(unit_decals[i].global_position))
	unit_decals.clear()
	base.queue_free()

func update(user: User, _delta: float) -> void:
	var pos: Vector3 = Util.mouse_raycast_3d_position(user.camera_rig.camera, user.camera_rig.mouse_current_position)
	if pos == Vector3.ZERO: return
	
	var distance: float = base.global_position.distance_to(pos)
	
	if not base.visible:
		if distance >= PADDING: base.visible = true
	if distance != 0:
		set_columns(ceil(distance / PADDING))
	base.look_at(pos + Vector3(0.01, 0.01, 0.01), Vector3.UP)
	base.rotation.x = 0
	
	# Set global_position by finding center of object.start_pos and pos.
	var x: float = (base.global_position.x + user.mouse_global_position.x) / 2
	var y: float = (base.global_position.y + user.mouse_global_position.y) / 2
	var z: float = (base.global_position.z + user.mouse_global_position.z) / 2
	formation_box.global_position = Vector3(x, y, z)

# Set number of columns and adjust formation layout.
func set_columns(num: int) -> void:
	if num > unit_decals.size() or num <= 0: return
	@warning_ignore("integer_division")
	var val: float = unit_decals.size() / num
	var units_per_col = floor(val)
	var col: int = 0
	var row: int = 0
	for decal in unit_decals:
		decal.position = Vector3(PADDING * row, 0, -PADDING / 2 - PADDING * col)
		row += 1
		if row == units_per_col:
			row = 0
			col += 1

func set_target(user: User, target: Node3D) -> void:
	if not user.hold_group: user.get_selected_group().clear_pathing()
	user.get_selected_group().assign_target(target)
