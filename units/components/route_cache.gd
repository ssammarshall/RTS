class_name RouteCache extends RefCounted
# Legs many units repeat (a gatherer's pile to mine and back) share their paths per (from node, to node).
# A unit starting the leg at the from node queries it, units starting it meanwhile wait for that query.
# A route is dropped once the navigation map merges a re-bake of a tile under it.

const MAX_ROUTES := 4 # Per key: units spread around a building, and a route only serves units near it.

static var _routes := {} # key -> Array of Route, each queried from a different spot at the from node
static var _waiting := {} # key -> Array of PathFinders waiting for the key's query
static var _grid_id := 0
static var _change := 0

class Route:
	var path: PackedVector3Array
	var tiles: Rect2i

	func _init(route_path: PackedVector3Array, route_tiles: Rect2i) -> void:
		path = route_path
		tiles = route_tiles

static func key(from: Node3D, to: Node3D) -> String:
	return "%d>%d" % [from.get_instance_id(), to.get_instance_id()]

# Every route returned is up to date with the navigation map.
static func get_routes(route_key: String) -> Array:
	_sync()
	return _routes.get(route_key, [])

static func is_full(route_key: String) -> bool:
	return _routes.get(route_key, []).size() >= MAX_ROUTES

static func is_querying(route_key: String) -> bool:
	return _waiting.has(route_key)

# `from` is only used by the request that starts the query: it has to be a unit standing at the from node.
static func request(route_key: String, from: Vector3, to: Vector3, finder: PathFinder) -> void:
	if _waiting.has(route_key):
		_waiting[route_key].append(finder)
		return
	_waiting[route_key] = [finder]
	PathFinder.queries += 1
	PathQuery.request(from, to, _take.bind(route_key))

# A route queried before a re-bake under it reached the map isn't kept, and its units query their own paths.
static func _take(query: PathQuery, route_key: String) -> void:
	var finders: Array = _waiting[route_key]
	_waiting.erase(route_key)
	_sync()
	var route: Route = null
	if not query.path.is_empty():
		var grid := Map.current.nav_grid
		var tiles: Rect2i = grid.tiles_under(query.path)
		if not grid.changed_since(tiles, query.change):
			route = Route.new(query.path, tiles)
			var routes: Array = _routes.get_or_add(route_key, [])
			if routes.size() < MAX_ROUTES: routes.append(route)
	for finder: PathFinder in finders: finder.take_route(route_key, route)

static func _sync() -> void:
	var grid := Map.current.nav_grid
	if grid.get_instance_id() != _grid_id:
		_routes.clear()
		_grid_id = grid.get_instance_id()
		_change = grid.changes
		return
	if _change == grid.changes: return
	var since := _change
	for route_key: String in _routes.keys():
		var kept: Array = _routes[route_key].filter(func(route: Route) -> bool: return not grid.changed_since(route.tiles, since))
		if kept.is_empty(): _routes.erase(route_key)
		else: _routes[route_key] = kept
	_change = grid.changes
