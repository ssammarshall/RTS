class_name Building extends StaticBody3D

signal removed(building: Building)

@export var title: String
@export var resource: StrategicResource # eventually update to have more than one type of resource
var resource_limit: int = 1000
@export var item_data: ItemData
var job: Job = null

@export_category("RequiredChildren")
@export var mesh: Node3D
@export var preview_mesh: MeshInstance3D
@export var collision_shape: CollisionShape3D
@export var building_area: Area3D
@export var building_area_collision_shape: CollisionShape3D
@export var selectable_object: SelectableObject

# Construction.
var construction_complete := false
var pending_workers: Array[Unit] = []

# Preview.
var preview_material := ShaderMaterial.new()

var _reach_inverse: Transform3D # Placed buildings don't move, so the area's frame is cached on first use.
var _reach_half := Vector2.ZERO

func _ready() -> void:
	select(false)
	
	set_building_collision_layer(Global.COLLISION_LAYER.BUILDING, true)
	building_area.set_collision_layer_value(Global.COLLISION_LAYER.BUILDING, true)
	building_area.set_collision_mask_value(Global.COLLISION_LAYER.BUILDING, true)
	
	preview_mesh.material_overlay = preview_material
	preview_material.shader = Global.BUILDING_PREVIEW

# This function needs to be overriden by Node inheriting Building.
func unit_interaction(_unit: Unit) -> void:
	pass

func remove() -> void:
	removed.emit(self)
	for unit in pending_workers:
		if is_instance_valid(unit) and unit.command is InteractCommand and (unit.command as InteractCommand).target == self:
			unit.set_command(null)
	pending_workers.clear()
	queue_free()

func assign_worker(unit: Unit) -> void:
	if construction_complete:
		give_job(unit)
	elif not pending_workers.has(unit):
		pending_workers.append(unit)
		unit.set_command(InteractCommand.new(self))

func give_job(unit: Unit) -> void:
	if job: unit.set_job(job.copy())

func select(value: bool) -> void:
	selectable_object.is_selected = value

func display_building_preview(display: bool) -> void:
	if display:
		mesh.hide()
		preview_mesh.show()
		set_preview_color(Global.WHITE_TRANSPARENT)
	else:
		mesh.show()
		preview_mesh.hide()

# How far along a move from `a` to `b` (0 to 1) a unit with an interaction area of `radius` first touches this
# building's area, on the ground plane; 0 if it already does, -1 if it doesn't on the way.
# The area's box grown by the radius has rounded corners; the box grown square is a cheap first check.
func reach_along(a: Vector3, b: Vector3, radius: float) -> float:
	if _reach_half == Vector2.ZERO:
		var box := building_area_collision_shape.shape as BoxShape3D
		if not box: return -1.0
		_reach_inverse = building_area_collision_shape.global_transform.affine_inverse()
		_reach_half = Vector2(box.size.x, box.size.z) * 0.5
	var local_a := _reach_inverse * a
	var local_b := _reach_inverse * b
	var p := Vector2(local_a.x, local_a.z)
	var d := Vector2(local_b.x - local_a.x, local_b.z - local_a.z)
	var h := _reach_half
	if is_inf(_box_entry(p, d, h + Vector2(radius, radius))): return -1.0
	var enter := minf(_box_entry(p, d, h + Vector2(radius, 0.0)), _box_entry(p, d, h + Vector2(0.0, radius)))
	for corner in [h, -h, Vector2(h.x, -h.y), Vector2(-h.x, h.y)]:
		enter = minf(enter, _circle_entry(p - corner, d, radius))
	return enter if is_finite(enter) else -1.0

# The fraction of the move p → p + d at which it enters the box -half..half, or INF if it doesn't.
static func _box_entry(p: Vector2, d: Vector2, half: Vector2) -> float:
	var x := _slab(p.x, p.x + d.x, half.x)
	var z := _slab(p.y, p.y + d.y, half.y)
	var enter := maxf(x.x, z.x)
	return enter if enter <= minf(x.y, z.y) else INF

# The fraction of the move p → p + d at which it comes within radius of the origin, or INF if it doesn't.
static func _circle_entry(p: Vector2, d: Vector2, radius: float) -> float:
	var c := p.length_squared() - radius * radius
	if c <= 0.0: return 0.0
	var a := d.length_squared()
	var b := p.dot(d)
	var discriminant := b * b - a * c
	if a == 0.0 or discriminant < 0.0: return INF
	var t := (-b - sqrt(discriminant)) / a
	return t if t >= 0.0 and t <= 1.0 else INF

# The part of a move from `a` to `b` (as fractions 0 to 1) that lies within -half..half on one axis; empty if enter > leave.
static func _slab(a: float, b: float, half: float) -> Vector2:
	var d := b - a
	if is_zero_approx(d): return Vector2(0.0, 1.0) if absf(a) <= half else Vector2(1.0, 0.0)
	var t0 := (-half - a) / d
	var t1 := (half - a) / d
	return Vector2(maxf(minf(t0, t1), 0.0), minf(maxf(t0, t1), 1.0))

func get_item_type() -> ItemData.Type:
	return item_data.type if item_data else ItemData.Type.NONE

func set_building_collision_layer(layer: int, value: bool) -> void:
	if layer == 0 or layer > 32: return
	
	set_collision_layer_value(layer, value)

func set_preview_color(color: Color) -> void:
	preview_mesh.set_instance_shader_parameter("instance_color", color)

func start_construction() -> void:
	display_building_preview(false) # Show Building.
	set_building_collision_layer(Global.COLLISION_LAYER.WORLD, true) # Allow Building to interact with world.
	construction_complete = true
	SignalBus.building_constructed.emit(self)

	for unit in pending_workers:
		if not is_instance_valid(unit): continue
		if unit.command is InteractCommand and (unit.command as InteractCommand).target == self:
			give_job(unit)
	pending_workers.clear()
