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
