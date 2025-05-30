class_name Map extends Node3D

@export var nav_region: NavigationRegion3D

var buildings: Array[Building] = []

func _ready() -> void:
	SignalBus.building_placed.connect(Callable(_on_building_placed))
	SignalBus.building_remove_last.connect(Callable(_on_building_remove_last))
	SignalBus.building_constructed.connect(Callable(_on_building_constructed))
	
	nav_region.bake_finished.connect(Callable(_on_bake_finished))

func _on_building_placed(building: Building) ->  void:
	building.get_parent().remove_child(building)
	buildings.append(building)
	nav_region.add_child(building)

func _on_building_remove_last() -> void:
	var size: int = buildings.size()
	if size > 0:
		if buildings[size - 1].construction_complete: return # Cannot remove last on already constructed Building.
		buildings[size - 1].queue_free()

func _on_building_constructed(building: Building) -> void:
	if not buildings.has(building): return
	
	if nav_region.is_baking(): await nav_region.bake_finished
	nav_region.bake_navigation_mesh(true)

func _on_bake_finished() -> void:
	print("map finished baking navigation")
