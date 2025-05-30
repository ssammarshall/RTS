class_name PaintObject extends Node3D

enum Type {
	Point,
	Line,
	Box
}
var type: Type

var mesh: MeshInstance3D
var start_pos: Vector3 = Vector3.ZERO

func _init(typ: Type) -> void:
	type = typ
	match type:
		Type.Point:
			mesh = create_point()
		Type.Line:
			pass
		Type.Box:
			mesh = create_box()
	add_child(mesh)

func create_point(radius: float = .5, color := Color.WHITE_SMOKE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	var material := ORMMaterial3D.new()
	
	mesh_instance.mesh = sphere_mesh
	
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2
	sphere_mesh.material = material
	
	material.albedo_color = color
	
	return mesh_instance

func create_box(height: float = 1, width: float = 1, color := Color.WHITE_SMOKE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	var material := ORMMaterial3D.new()
	
	mesh_instance.mesh = box_mesh
	
	box_mesh.size = Vector3(width, height, width)
	box_mesh.material = material
	
	material.albedo_color = color
	
	return mesh_instance
