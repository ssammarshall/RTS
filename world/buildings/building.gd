class_name Building extends StaticBody3D

@export var title: String
@export var resource: StrategicResource # eventually update to have more than one type of resource
var resource_limit: int = 1000
@export var item: PackedScene

@export_category("RequiredChildren")
@export var mesh: Node3D
@export var preview_mesh: MeshInstance3D
@export var collision_shape: CollisionShape3D
@export var area: Area3D
@export var area_collision_shape: CollisionShape3D
@export var selectable_object: SelectableObject

# Construction.
var construction_complete := false

# Preview.
var preview_material := ShaderMaterial.new()

func _ready() -> void:
	select(false)
	
	preview_mesh.material_overlay = preview_material
	preview_material.shader = Global.BUILDING_PREVIEW

# This function needs to be overriden by Node inheriting Building.
func unit_interaction(unit: Unit) -> void:
	# TEST
	if item:
		unit.equipped_item = item.instantiate() as Item
		unit.add_child(unit.equipped_item)

func update_resource_totals() -> void:
	if not resource: return
	if resource.amount > resource_limit:
		resource.amount = resource_limit

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

func set_building_collision_layer(layer: int, value: bool) -> void:
	if layer < 0 or layer > 32: return
	
	set_collision_layer_value(layer, value)

func set_preview_color(color: Color) -> void:
	preview_mesh.set_instance_shader_parameter("instance_color", color)

func start_construction() -> void:
	display_building_preview(false) # Show Building.
	set_building_collision_layer(1, true) # Allow Building to interact with world.
	construction_complete = true
	SignalBus.building_constructed.emit(self)
