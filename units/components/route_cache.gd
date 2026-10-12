class_name RouteCache extends RefCounted
# Legs many units repeat (a gatherer's pile to mine and back) share their paths per (from node, to node).
# A unit starting the leg at the from node queries it, units starting it meanwhile wait for that query.
# Every route is dropped when the navigation map changes.

const MAX_ROUTES := 4 # Per key: units spread around a building, and a route only serves units near it.

static var _routes := {} # key -> Array of PackedVector3Array, each queried from a different spot at the from node
static var _waiting := {} # key -> Array of PathFinders waiting for the key's query
static var _map_iteration := -1

static func key(from: Node3D, to: Node3D) -> String:
	return "%d>%d" % [from.get_instance_id(), to.get_instance_id()]

static func get_routes(route_key: String, map: RID) -> Array:
	_sync(map)
	return _routes.get(route_key, [])

static func is_full(route_key: String) -> bool:
	return _routes.get(route_key, []).size() >= MAX_ROUTES

static func is_querying(route_key: String) -> bool:
	return _waiting.has(route_key)

# `from` is only used by the request that starts the query: it has to be a unit standing at the from node.
static func request(route_key: String, map: RID, from: Vector3, to: Vector3, finder: PathFinder) -> void:
	if _waiting.has(route_key):
		_waiting[route_key].append(finder)
		return
	_waiting[route_key] = [finder]
	PathFinder.queries += 1
	PathQuery.request(from, to, _take.bind(route_key, map))

# A route queried on an older map isn't kept, and its units query their own paths.
static func _take(query: PathQuery, route_key: String, map: RID) -> void:
	var finders: Array = _waiting[route_key]
	_waiting.erase(route_key)
	_sync(map)
	var route := query.path if query.iteration == _map_iteration else PackedVector3Array()
	if not route.is_empty():
		var routes: Array = _routes.get_or_add(route_key, [])
		if routes.size() < MAX_ROUTES: routes.append(route)
	for finder: PathFinder in finders: finder.take_route(route_key, route)

static func _sync(map: RID) -> void:
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if iteration == _map_iteration: return
	_routes.clear()
	_map_iteration = iteration
