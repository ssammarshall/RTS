class_name Heightmap extends RefCounted
# Ground heights on a regular grid, sampled with bilinear interpolation. Baked from the terrain's collision triangles:
# each grid point takes the height of the highest triangle over it, like a ray cast straight down.

const EDGE := 0.0001 # In cells: grid points this close outside a triangle still count as on it, so shared edges have no gaps.

var origin := Vector2.ZERO
var cell_size := 1.0
var width := 0
var depth := 0
var heights := PackedFloat32Array()
var filled := 0 # Grid points no triangle covered, filled from their neighbours.

func bounds() -> Rect2:
	return Rect2(origin, Vector2(width - 1, depth - 1) * cell_size)

func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / cell_size, 0.0, width - 1.0001)
	var fz := clampf((z - origin.y) / cell_size, 0.0, depth - 1.0001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * width + ix
	var near := lerpf(heights[i], heights[i + 1], tx)
	var far := lerpf(heights[i + width], heights[i + width + 1], tx)
	return lerpf(near, far, tz)

# The triangles of every concave collision shape under `root` whose body is on a layer in `mask`, in global space.
# Main thread only, since it reads the nodes' transforms.
static func terrain_faces(root: Node, mask: int) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		var body := shape_node.get_parent() as CollisionObject3D
		var shape := shape_node.shape as ConcavePolygonShape3D
		if body and shape and body.collision_layer & mask: faces.append_array(shape_node.global_transform * shape.get_faces())
	return faces

# A heightmap with `cell`-metre cells over `faces` (every three points a triangle). Safe to run on a worker thread.
static func bake(faces: PackedVector3Array, cell: float) -> Heightmap:
	var map := Heightmap.new()
	if faces.is_empty(): return map
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for v in faces:
		low = low.min(Vector2(v.x, v.z))
		high = high.max(Vector2(v.x, v.z))
	map.origin = low
	map.cell_size = cell
	map.width = int((high.x - low.x) / cell) + 1
	map.depth = int((high.y - low.y) / cell) + 1
	var samples := PackedFloat32Array()
	samples.resize(map.width * map.depth)
	samples.fill(-INF)
	for i in range(0, faces.size(), 3):
		_raster(faces[i], faces[i + 1], faces[i + 2], map, samples)
	map.filled = _fill(samples, map.width)
	map.heights = samples
	return map

# Writes triangle abc's height at every grid point it covers, row by row between its lowest and highest z.
static func _raster(a: Vector3, b: Vector3, c: Vector3, map: Heightmap, samples: PackedFloat32Array) -> void:
	var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if absf(area) < 1e-9: return # Vertical, seen edge on from above.
	var dhdx := ((b.y - a.y) * (c.z - a.z) - (c.y - a.y) * (b.z - a.z)) / area
	var dhdz := ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / area
	var t := a
	if b.z < a.z:
		a = b
		b = t
	if c.z < b.z:
		t = b
		b = c
		c = t
	if b.z < a.z:
		t = a
		a = b
		b = t
	var long_slope := (c.x - a.x) / (c.z - a.z)
	var top_slope := (b.x - a.x) / (b.z - a.z) if b.z > a.z else 0.0
	var bottom_slope := (c.x - b.x) / (c.z - b.z) if c.z > b.z else 0.0
	var inverse := 1.0 / map.cell_size
	var step := dhdx * map.cell_size
	var last_col := map.width - 1
	for row in range(maxi(ceili((a.z - map.origin.y) * inverse - EDGE), 0), mini(floori((c.z - map.origin.y) * inverse + EDGE), map.depth - 1) + 1):
		var z := map.origin.y + row * map.cell_size
		var x1 := a.x + (z - a.z) * long_slope
		var x2 := a.x + (z - a.z) * top_slope if z < b.z else b.x + (z - b.z) * bottom_slope
		var from := maxi(ceili((minf(x1, x2) - map.origin.x) * inverse - EDGE), 0)
		var to := mini(floori((maxf(x1, x2) - map.origin.x) * inverse + EDGE), last_col)
		var h := a.y + dhdx * (map.origin.x + from * map.cell_size - a.x) + dhdz * (z - a.z)
		var i := row * map.width + from
		for col in range(from, to + 1):
			if h > samples[i]: samples[i] = h
			h += step
			i += 1

# Grid points no triangle covered (holes, or past a ragged edge) take the average of their covered neighbours,
# a ring at a time. Returns how many there were.
static func _fill(samples: PackedFloat32Array, columns: int) -> int:
	var missing := PackedInt32Array()
	var at := samples.find(-INF)
	while at >= 0:
		missing.append(at)
		at = samples.find(-INF, at + 1)
	var count := missing.size()
	while not missing.is_empty():
		var ring := PackedFloat32Array()
		ring.resize(missing.size())
		for m in missing.size():
			at = missing[m]
			var total := 0.0
			var found := 0
			for n in [at - 1, at + 1, at - columns, at + columns]:
				if n < 0 or n >= samples.size() or (n == at - 1 and at % columns == 0) or (n == at + 1 and n % columns == 0): continue
				if samples[n] == -INF: continue
				total += samples[n]
				found += 1
			ring[m] = total / found if found else -INF
		var still := PackedInt32Array()
		for m in missing.size():
			if ring[m] == -INF: still.append(missing[m])
			else: samples[missing[m]] = ring[m]
		if still.size() == missing.size():
			for left in still: samples[left] = 0.0
			break
		missing = still
	return count
