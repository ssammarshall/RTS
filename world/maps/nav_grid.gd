class_name NavGrid extends Node3D
# Tiled navigation component.

const NAV_MESH_TEMPLATE: NavigationMesh = preload("res://world/maps/nav_tile_template.tres")
const JOIN_QUIET := 0.5
const MERGES := 2
const TILES_PER_CHANGE := 16
const LOG_SIZE := 512

@export var tile_size: float = 48.0
@export var carve_height_margin: float = 2.0
@export var edge_connection_margin: float = 1.5
@export var query_pad: float = 48.0

var nav_map: RID
var changes := 0

var _base_source := NavigationMeshSourceGeometryData3D.new()
var _terrain_vertices := PackedFloat32Array()
var _terrain_indices := PackedInt32Array()
var _tiles: Array[NavigationRegion3D] = []
var _rids: Array[RID] = []
var _grid_cols: int = 0
var _grid_rows: int = 0
var _map_aabb: AABB
var _baking := {}
var _bakes := 0
var _obstructions := {}
var _dirty := {}
var _flush_queued := false
var _joining := false
var _merging := {}
var _log_tiles: Array[Rect2i] = []
var _log_changes := PackedInt32Array()
var _forgotten := 0

# Parse terrain_root's static geometry and build/bake the tile grid.
# Call once at startup.
func build(terrain_root: Node3D) -> void:
	nav_map = get_world_3d().navigation_map
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)
	NavigationServer3D.map_set_edge_connection_margin(nav_map, edge_connection_margin)

	_parse_terrain(terrain_root)
	_read_footprints()
	_rebuild_source()
	_compute_bounds()
	_build_tiles()
	bake_all()
	_joining = not _tiles.is_empty()
	NavigationServer3D.map_changed.connect(_on_map_changed)

# Applied at the end of the frame, so many changes at once re-bake each tile once.
func add_obstruction(building: Building) -> void:
	if _obstructions.has(building): return
	_obstructions[building] = []
	_queue_flush()

func remove_obstruction(building: Building) -> void:
	if not _obstructions.has(building): return
	var obstruction: Array = _obstructions[building]
	_obstructions.erase(building)
	if obstruction.is_empty(): return
	_mark_dirty(obstruction)
	_queue_flush()

func bake_all() -> void:
	for i in _tiles.size():
		_bake_tile(i)

func is_baking() -> bool:
	return not _baking.is_empty()

# The tiles a path from `from` to `to` searches: the box around the two, grown by query_pad.
func regions_between(from: Vector3, to: Vector3) -> Array[RID]:
	return _regions_in(_tile_range(AABB(from, Vector3.ZERO).expand(to).grow(query_pad)))

# pos's tile and the tiles around it.
func regions_around(pos: Vector3) -> Array[RID]:
	var col := clampi(floori((pos.x - _map_aabb.position.x) / tile_size), 0, _grid_cols - 1)
	var row := clampi(floori((pos.z - _map_aabb.position.z) / tile_size), 0, _grid_rows - 1)
	var c0 := maxi(col - 1, 0)
	var r0 := maxi(row - 1, 0)
	return _regions_in(Rect2i(c0, r0, mini(col + 2, _grid_cols) - c0, mini(row + 2, _grid_rows) - r0))

# A row of tiles at a time: requests build these on the main thread.
func _regions_in(tiles: Rect2i) -> Array[RID]:
	var regions: Array[RID] = []
	for row in range(tiles.position.y, tiles.end.y):
		regions.append_array(_rids.slice(row * _grid_cols + tiles.position.x, row * _grid_cols + tiles.end.x))
	return regions

func tiles_under(path: PackedVector3Array) -> Rect2i:
	var aabb := AABB(path[0], Vector3.ZERO)
	for point in path: aabb = aabb.expand(point)
	return _tile_range(aabb)

# Whether the map has merged a re-bake of any of `tiles` since change number `change`. One too old to remember counts.
func changed_since(tiles: Rect2i, change: int) -> bool:
	if change >= changes: return false
	if change < _forgotten: return true
	for i in range(_log_changes.size() - 1, -1, -1):
		if _log_changes[i] <= change: return false
		if _log_tiles[i].intersects(tiles): return true
	return false

# The closest navmesh point on pos's tile and the tiles around it, without scanning the whole map.
func closest_point(pos: Vector3) -> Vector3:
	return closest_on(regions_around(pos), pos)

# Only calls the navigation server, so it can run on a worker thread.
static func closest_on(regions: Array[RID], pos: Vector3) -> Vector3:
	var closest := pos
	var best := INF
	for region in regions:
		var point := NavigationServer3D.region_get_closest_point(region, pos)
		var distance := point.distance_squared_to(pos)
		if distance < best:
			best = distance
			closest = point
	return closest

# Walk the terrain once and cache its geometry; every tile bakes from this.
func _parse_terrain(terrain_root: Node3D) -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(NAV_MESH_TEMPLATE, source, terrain_root)
	_terrain_vertices = source.get_vertices()
	_terrain_indices = source.get_indices()

# A new source each time: a tile still baking on a worker thread keeps reading the one it started with.
func _rebuild_source() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	source.set_vertices(_terrain_vertices)
	source.set_indices(_terrain_indices)
	for obstruction: Array in _obstructions.values():
		source.add_projected_obstruction(obstruction[0], obstruction[1], obstruction[2], false)
	_base_source = source

func _queue_flush() -> void:
	if _tiles.is_empty() or _flush_queued: return
	_flush_queued = true
	_flush.call_deferred()

func _flush() -> void:
	_flush_queued = false
	if not is_inside_tree(): return
	for obstruction: Array in _read_footprints(): _mark_dirty(obstruction)
	_rebuild_source()
	for i in _dirty: _bake_tile(i)
	_dirty.clear()

# Read late: a building's collision shape isn't in the tree yet when the building enters it.
func _read_footprints() -> Array[Array]:
	var read: Array[Array] = []
	for building: Building in _obstructions.keys():
		if not _obstructions[building].is_empty(): continue
		var obstruction := _obstruction(building)
		if obstruction.is_empty(): _obstructions.erase(building)
		else:
			_obstructions[building] = obstruction
			read.append(obstruction)
	return read

func _mark_dirty(obstruction: Array) -> void:
	for i in _tiles_overlapping(_footprint_aabb(obstruction[0])): _dirty[i] = true

# Derive the grid extents from the parsed geometry so tiles cover exactly the map.
func _compute_bounds() -> void:
	var verts: PackedFloat32Array = _terrain_vertices
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
			_rids.append(region.get_rid())

func _tile_aabb(col: int, row: int) -> AABB:
	var pos := Vector3(
		_map_aabb.position.x + col * tile_size,
		_map_aabb.position.y,
		_map_aabb.position.z + row * tile_size)
	return AABB(pos, Vector3(tile_size, _map_aabb.size.y, tile_size))

# Each bake writes a mesh of its own, and only a tile's latest bake is applied: re-baking the mesh a region already
# had, while the map was still merging it, lost the newer bake.
func _bake_tile(index: int) -> void:
	_bakes += 1
	var bake := _bakes
	_baking[index] = bake
	var mesh := NAV_MESH_TEMPLATE.duplicate() as NavigationMesh
	mesh.filter_baking_aabb = _tiles[index].navigation_mesh.filter_baking_aabb
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, _base_source, _on_tile_baked.bind(index, bake, mesh))

func _on_tile_baked(index: int, bake: int, mesh: NavigationMesh) -> void:
	if _baking.get(index, -1) != bake: return
	_baking.erase(index)
	if not is_inside_tree(): return
	_tiles[index].navigation_mesh = mesh
	@warning_ignore("integer_division")
	_merging[Rect2i(index % _grid_cols, index / _grid_cols, 1, 1)] = MERGES

func _on_map_changed(map: RID) -> void:
	if map != nav_map: return
	_count_change()
	if not _joining or is_baking() or not is_inside_tree(): return
	get_tree().create_timer(JOIN_QUIET).timeout.connect(_join.bind(NavigationServer3D.map_get_iteration_id(map)))

# Re-applying a tile's mesh starts a build, which joins seams across the whole map.
func _join(iteration: int) -> void:
	if not _joining or NavigationServer3D.map_get_iteration_id(nav_map) != iteration: return
	_joining = false
	NavigationServer3D.region_set_navigation_mesh(_rids[0], _tiles[0].navigation_mesh)
	_merging[Rect2i(0, 0, _grid_cols, _grid_rows)] = MERGES

# A tile's new mesh counts as changed in the next MERGES map changes: one applied while the map was building only
# reaches the build after. Many tiles at once (start-up) count as the box around them.
func _count_change() -> void:
	if _merging.is_empty(): return
	changes += 1
	var rects: Array = _merging.keys()
	if rects.size() > TILES_PER_CHANGE:
		var bounds: Rect2i = rects[0]
		for rect: Rect2i in rects: bounds = bounds.merge(rect)
		rects = [bounds]
	for rect: Rect2i in rects:
		_log_tiles.append(rect)
		_log_changes.append(changes)
	for rect: Rect2i in _merging.keys():
		_merging[rect] -= 1
		if _merging[rect] == 0: _merging.erase(rect)
	if _log_tiles.size() <= LOG_SIZE: return
	var half := _log_tiles.size() >> 1
	_log_tiles = _log_tiles.slice(half)
	_log_changes = _log_changes.slice(half)
	_forgotten = _log_changes[0]

# A Building's solid collision shape as a projected obstruction: [outline, elevation, height], or empty on failure. It
# isn't a carve, so the bake widens it by the agent radius and paths keep a unit's width from the walls.
func _obstruction(building: Building) -> Array:
	var points := _collision_world_points(building)
	if points.size() < 3: return []

	var footprint := _footprint_hull(points)
	if footprint.size() < 3: return []

	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	return [footprint, min_y - carve_height_margin, (max_y - min_y) + carve_height_margin * 2.0]

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
	var tiles := _tile_range(aabb)
	var result: Array[int] = []
	for row in range(tiles.position.y, tiles.end.y):
		for col in range(tiles.position.x, tiles.end.x):
			result.append(row * _grid_cols + col)
	return result

# The columns and rows of the tiles whose slice intersects the (agent-radius-padded) AABB.
func _tile_range(aabb: AABB) -> Rect2i:
	var pad: float = NAV_MESH_TEMPLATE.agent_radius
	var c0 := clampi(floori((aabb.position.x - pad - _map_aabb.position.x) / tile_size), 0, _grid_cols - 1)
	var c1 := clampi(floori((aabb.position.x + aabb.size.x + pad - _map_aabb.position.x) / tile_size), 0, _grid_cols - 1)
	var r0 := clampi(floori((aabb.position.z - pad - _map_aabb.position.z) / tile_size), 0, _grid_rows - 1)
	var r1 := clampi(floori((aabb.position.z + aabb.size.z + pad - _map_aabb.position.z) / tile_size), 0, _grid_rows - 1)
	return Rect2i(c0, r0, c1 - c0 + 1, r1 - r0 + 1)
