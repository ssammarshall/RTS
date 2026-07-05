class_name FormationSort extends Node

func set_formation(group: Group) -> void:
	match group.current_formation:
		Group.FORMATION.BOX:
			box_formation(group)
		Group.FORMATION.SCATTER:
			pass

func box_formation(group: Group) -> void:
	var center: Vector3 = center_pos(group)

func center_pos(group: Group) -> Vector3:
	if group == null: return Vector3.ZERO
	
	var num_of_units: int = group.size()
	if num_of_units <= 0: return Vector3.ZERO
	
	var center := Vector3.ZERO
	var group_global_pos: Array[Vector3] = group.get_unit_positions()
	
	for i in num_of_units:
		center += group_global_pos[i]
	center = center / num_of_units
	
	return center



# 
