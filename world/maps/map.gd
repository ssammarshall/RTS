class_name Map extends Node3D

## Owns the building list and delegates navigation to its [NavGrid] component,
## which carves placed buildings out of a tiled navigation mesh.

@export var nav_grid: NavGrid
@export var terrain_root: Node3D

var buildings: Array[Building] = []

func _ready() -> void:
	SignalBus.building_placed.connect(Callable(_on_building_placed))
	SignalBus.building_remove_last.connect(Callable(_on_building_remove_last))
	SignalBus.building_constructed.connect(Callable(_on_building_constructed))

	nav_grid.build(terrain_root)

func _on_building_placed(building: Building) -> void:
	building.get_parent().remove_child(building)
	buildings.append(building)
	add_child(building)

func _on_building_remove_last() -> void:
	var size: int = buildings.size()
	if size > 0:
		var last_building: Building = buildings[size - 1]
		if last_building.construction_complete: return # Cannot remove last on already constructed Building.
		buildings.remove_at(size - 1)
		last_building.queue_free()

func _on_building_constructed(building: Building) -> void:
	if not buildings.has(building): return
	nav_grid.carve_building(building)

func find_buildings(building_type: Variant, _resource: StrategicResource = null) -> Array[Building]:
	var building_list: Array[Building]
	for building in buildings:
		if is_instance_of(building, building_type):
			if _resource:
				if building.resource.type == _resource.type: building_list.append(building)
				else: continue
			else: building_list.append(building)
	return building_list
