class_name Map extends Node3D

## Owns the building list and delegates navigation to its [NavGrid] component,
## which keeps every building units collide with out of a tiled navigation mesh.
## Every [Building] under the map is in [member building_grid]; placement previews aren't under it.
## The terrain's [Heightmap] is baked on a worker thread when the map loads.

signal heightmap_baked

const BUILDING_CELL := 32.0
const HEIGHTMAP_CELL := 1.0

static var current: Map

@export var nav_grid: NavGrid
@export var terrain_root: Node3D

var buildings: Array[Building] = []
var building_grid := SpatialGrid.new(BUILDING_CELL)

var _heightmap: Heightmap
var _heightmap_task := -1

func _enter_tree() -> void:
	current = self

func _exit_tree() -> void:
	if current == self: current = null
	_finish_heightmap()

func _ready() -> void:
	SignalBus.building_placed.connect(Callable(_on_building_placed))
	SignalBus.building_remove_last.connect(Callable(_on_building_remove_last))

	nav_grid.build(terrain_root)
	var faces := Heightmap.terrain_faces(terrain_root, 1 << (Global.COLLISION_LAYER.TERRAIN - 1))
	_heightmap_task = WorkerThreadPool.add_task(_bake_heightmap.bind(faces))

# Waits for the bake if it's still running, which only happens right after the map loads.
func get_heightmap() -> Heightmap:
	_finish_heightmap()
	return _heightmap

func _bake_heightmap(faces: PackedVector3Array) -> void:
	_heightmap = Heightmap.bake(faces, HEIGHTMAP_CELL)
	_finish_heightmap.call_deferred()

func _finish_heightmap() -> void:
	if _heightmap_task < 0: return
	WorkerThreadPool.wait_for_task_completion(_heightmap_task)
	_heightmap_task = -1
	heightmap_baked.emit()

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
		last_building.remove()

func find_buildings(building_type: Variant, _resource: StrategicResource = null) -> Array[Building]:
	var building_list: Array[Building]
	for building in buildings:
		if is_instance_of(building, building_type):
			if _resource:
				if building.resource.type == _resource.type: building_list.append(building)
				else: continue
			else: building_list.append(building)
	return building_list
