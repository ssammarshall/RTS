class_name SpatialGrid extends RefCounted
# Uniform grid on the ground plane (x, z). An item is filed under its cell and only re-filed when it moves into
# another one. Items are addressed by the handle insert() returns; handles of removed items are reused.
# Each item has a radius, which separation uses.

const GOLDEN_ANGLE := 2.39996

var cell_size: float

var _inverse: float
var _cells := {} # Cell key -> Array of handles. Empty cells are erased.
var _items: Array = []
var _positions := PackedVector2Array()
var _radii := PackedFloat32Array()
var _max_radius := 0.0 # The largest radius inserted, so separation knows how far to look.
var _keys := PackedInt64Array()
var _slots := PackedInt32Array() # Index of the handle in its cell's Array.
var _free := PackedInt32Array()

func _init(cell: float) -> void:
	cell_size = cell
	_inverse = 1.0 / cell

func insert(item: Object, pos: Vector2, radius := 0.0) -> int:
	var handle: int
	if _free.is_empty():
		handle = _items.size()
		_items.append(item)
		_positions.append(pos)
		_radii.append(radius)
		_keys.append(0)
		_slots.append(0)
	else:
		handle = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		_items[handle] = item
		_positions[handle] = pos
		_radii[handle] = radius
	_max_radius = maxf(_max_radius, radius)
	_file(handle, _key(pos))
	return handle

func remove(handle: int) -> void:
	_unfile(handle)
	_items[handle] = null
	_free.append(handle)

func move(handle: int, pos: Vector2) -> void:
	_positions[handle] = pos
	var key := _key(pos)
	if key == _keys[handle]: return
	_unfile(handle)
	_file(handle, key)

func set_radius(handle: int, radius: float) -> void:
	_radii[handle] = radius
	_max_radius = maxf(_max_radius, radius)

func size() -> int:
	return _items.size() - _free.size()

func cell_count() -> int:
	return _cells.size()

# Replaces the contents of `out` with the items within `radius` of `center`.
func query_circle(center: Vector2, radius: float, out: Array) -> void:
	out.clear()
	var r2 := radius * radius
	for x in range(floori((center.x - radius) * _inverse), floori((center.x + radius) * _inverse) + 1):
		for z in range(floori((center.y - radius) * _inverse), floori((center.y + radius) * _inverse) + 1):
			var cell = _cells.get(_cell_key(x, z))
			if cell == null: continue
			for handle: int in cell:
				if _positions[handle].distance_squared_to(center) <= r2: out.append(_items[handle])

# Replaces the contents of `out` with the items inside `rect`.
func query_rect(rect: Rect2, out: Array) -> void:
	out.clear()
	var end := rect.end
	for x in range(floori(rect.position.x * _inverse), floori(end.x * _inverse) + 1):
		for z in range(floori(rect.position.y * _inverse), floori(end.y * _inverse) + 1):
			var cell = _cells.get(_cell_key(x, z))
			if cell == null: continue
			for handle: int in cell:
				if rect.has_point(_positions[handle]): out.append(_items[handle])

# The push away from the other items closer to the item at `handle` than their two radii plus `gap`: each adds its
# direction away from it, weighted from 1 on top of it to 0 at that distance. An item exactly on top pushes in a
# direction picked from the handle. Items are first tested against the widest distance any pair could have.
func separation(handle: int, gap: float) -> Vector2:
	var center := _positions[handle]
	var own := _radii[handle] + gap
	var widest := own + _max_radius
	var widest2 := widest * widest
	var push := Vector2.ZERO
	for x in range(floori((center.x - widest) * _inverse), floori((center.x + widest) * _inverse) + 1):
		for z in range(floori((center.y - widest) * _inverse), floori((center.y + widest) * _inverse) + 1):
			var cell = _cells.get(_cell_key(x, z))
			if cell == null: continue
			for other: int in cell:
				var away := center - _positions[other]
				var l2 := away.length_squared()
				if l2 >= widest2: continue
				var distance := own + _radii[other]
				if l2 >= distance * distance: continue
				if l2 > 0.0:
					var l := sqrt(l2)
					push += away * ((distance - l) / (distance * l))
				elif other != handle: push += Vector2.from_angle(handle * GOLDEN_ANGLE)
	return push

func _key(pos: Vector2) -> int:
	return _cell_key(floori(pos.x * _inverse), floori(pos.y * _inverse))

static func _cell_key(x: int, z: int) -> int:
	return (x << 32) + z

func _file(handle: int, key: int) -> void:
	var cell = _cells.get(key)
	if cell == null:
		cell = []
		_cells[key] = cell
	_keys[handle] = key
	_slots[handle] = cell.size()
	cell.append(handle)

func _unfile(handle: int) -> void:
	var key := _keys[handle]
	var cell: Array = _cells[key]
	var last: int = cell[cell.size() - 1]
	cell[_slots[handle]] = last
	_slots[last] = _slots[handle]
	cell.pop_back()
	if cell.is_empty(): _cells.erase(key)
