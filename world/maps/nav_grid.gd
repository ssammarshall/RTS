class_name NavGrid extends Node3D
# Tiled navigation component.

const NAV_MESH_TEMPLATE: NavigationMesh = preload("res://world/maps/nav_tile_template.tres")

@export var tile_size: float = 48.0
@export var carve_height_margin: float = 2.0
@export var edge_connection_margin: float = 1.5

var _base_source := NavigationMeshSourceGeometryData3D.new()
var _tiles: Array[NavigationRegion3D] = []
var _grid_cols: int = 0
var _grid_rows: int = 0
var _map_aabb: AABB

# Parse terrain_root's static geometry and build/bake the tile grid.
# Call once at startup.
func build(terrain_root: Node3D) -> void:
	var nav_map: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)
	NavigationServer3D.map_set_edge_connection_margin(nav_map, edge_connection_margin)

	_parse_terrain(terrain_root)
	_compute_bounds()
	_build_tiles()
	bake_all()

# Carve a Building's footprint out of the navmesh and rebake the tiles it touches.
func carve_building(building: Building) -> void:
	if _tiles.is_empty(): return
	var footprint := _add_obstruction(building)
	if footprint.is_empty(): return
	for i in _tiles_overlapping(_footprint_aabb(footprint)):
		_bake_tile(i)

# Rebuild every obstruction from the current constructed buildings and rebake all.
func rebuild(buildings: Array[Building]) -> void:
	_base_source.clear_projected_obstructions()
	for b in buildings:
		if b.construction_complete:
			_add_obstruction(b)
	bake_all()

func bake_all() -> void:
	for i in _tiles.size():
		_bake_tile(i)

# Walk the terrain once and cache its geometry; every tile bakes from this.
func _parse_terrain(terrain_root: Node3D) -> void:
	_base_source.clear()
	NavigationServer3D.parse_source_geometry_data(NAV_MESH_TEMPLATE, _base_source, terrain_root)

# Derive the grid extents from the parsed geometry so tiles cover exactly the map.
func _compute_bounds() -> void:
	var verts: PackedFloat32Array = _base_source.get_vertices()
	if verts.is_empty():
		push_warning("NavGrid: no source geometry parsed; tiles not built.")
		return

	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for i in range(0, verts.size(), 3):
		var v := Vector3(verts[i], verts[i + 1], verts[i + 2])
		min_v = min_v.min(v)
		max_v = max_v.max(v)

	_map_aabb = AABB(min_v, max_v - min_v)
	_grid_cols = maxi(1, ceili(_map_aabb.size.x / tile_size))
	_grid_rows = maxi(1, ceili(_map_aabb.size.z / tile_size))

# Create one region per grid cell, each restricted to its own slice via filter AABB.
func _build_tiles() -> void:
	for row in _grid_rows:
		for col in _grid_cols:
			var mesh := NAV_MESH_TEMPLATE.duplicate() as NavigationMesh
			mesh.filter_baking_aabb = _tile_aabb(col, row)
			var region := NavigationRegion3D.new()
			region.navigation_mesh = mesh
			add_child(region)
			_tiles.append(region)

func _tile_aabb(col: int, row: int) -> AABB:
	var pos := Vector3(
		_map_aabb.position.x + col * tile_size,
		_map_aabb.position.y,
		_map_aabb.position.z + row * tile_size)
	return AABB(pos, Vector3(tile_size, _map_aabb.size.y, tile_size))

# Bake a single tile off-thread from the cached source geometry (+ obstructions),
# then hand the finished mesh to the NavigationServer for that region.
func _bake_tile(index: int) -> void:
	var region := _tiles[index]
	var mesh: NavigationMesh = region.navigation_mesh
	NavigationServer3D.bake_from_source_geometry_data_async(
		mesh, _base_source,
		func() -> void: NavigationServer3D.region_set_navigation_mesh(region.get_rid(), mesh))

# Carve a Building's solid collision shape into the shared source geometry.
# Returns the world-space footprint outline carved, or empty on failure.
func _add_obstruction(building: Building) -> PackedVector3Array:
	var points := _collision_world_points(building)
	if points.size() < 3: return PackedVector3Array()

	var footprint := _footprint_hull(points)
	if footprint.size() < 3: return PackedVector3Array()

	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var elevation := min_y - carve_height_margin
	var height := (max_y - min_y) + carve_height_margin * 2.0
	_base_source.add_projected_obstruction(footprint, elevation, height, true)
	return footprint

# World-space vertices of a Building's collision shape.
func _collision_world_points(building: Building) -> PackedVector3Array:
	var shape_node := building.collision_shape
	if not shape_node: return PackedVector3Array()

	var local: PackedVector3Array
	var shape := shape_node.shape
	if shape is ConvexPolygonShape3D:
		local = (shape as ConvexPolygonShape3D).points
	elif shape is BoxShape3D:
		var e: Vector3 = (shape as BoxShape3D).size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					local.append(Vector3(sx * e.x, sy * e.y, sz * e.z))
	else:
		return PackedVector3Array()

	var xform := shape_node.global_transform
	var world: PackedVector3Array
	for p in local:
		world.append(xform * p)
	return world

# Convex hull of the points projected onto the XZ plane, as an open outline.
func _footprint_hull(points: PackedVector3Array) -> PackedVector3Array:
	var flat := PackedVector2Array()
	for p in points:
		flat.append(Vector2(p.x, p.z))

	var hull := Geometry2D.convex_hull(flat)
	# convex_hull closes the loop by repeating the first point; drop the duplicate.
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)

	var outline: PackedVector3Array
	for h in hull:
		outline.append(Vector3(h.x, 0.0, h.y))
	return outline

func _footprint_aabb(footprint: PackedVector3Array) -> AABB:
	var min_v := footprint[0]
	var max_v := footprint[0]
	for v in footprint:
		min_v = min_v.min(v)
		max_v = max_v.max(v)
	return AABB(min_v, max_v - min_v)

# Flat tile indices whose slice intersects the (agent-radius-padded) AABB.
func _tiles_overlapping(aabb: AABB) -> Array[int]:
	var pad: float = NAV_MESH_TEMPLATE.agent_radius
	var c0 := clampi(floori((aabb.position.x - pad - _map_aabb.position.x) / tile_size), 0, _grid_cols - 1)
	var c1 := clampi(floori((aabb.position.x + aabb.size.x + pad - _map_aabb.position.x) / tile_size), 0, _grid_cols - 1)
	var r0 := clampi(floori((aabb.position.z - pad - _map_aabb.position.z) / tile_size), 0, _grid_rows - 1)
	var r1 := clampi(floori((aabb.position.z + aabb.size.z + pad - _map_aabb.position.z) / tile_size), 0, _grid_rows - 1)

	var result: Array[int] = []
	for row in range(r0, r1 + 1):
		for col in range(c0, c1 + 1):
			result.append(row * _grid_cols + col)
	return result
