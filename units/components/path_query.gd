class_name PathQuery extends RefCounted
# A path query searches only the tiles around its leg, with no limit on the polygons it searches. A path that ends short
# of the target's closest point went around outside those tiles, so the whole map is searched instead.

const SHORT := 1.0

static var fallbacks := 0

static func find(from: Vector3, to: Vector3) -> PackedVector3Array:
	var grid := Map.current.nav_grid
	var params := NavigationPathQueryParameters3D.new()
	params.map = grid.get_world_3d().navigation_map
	params.start_position = from
	params.target_position = to
	params.path_search_max_polygons = 0
	params.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	params.included_regions = grid.regions_between(from, to)
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(params, result)
	var path := result.path
	if path.is_empty(): return path
	var gap := path[path.size() - 1].distance_to(to)
	if gap <= SHORT or gap <= grid.closest_point(to).distance_to(to) + SHORT: return path
	fallbacks += 1
	params.included_regions = []
	NavigationServer3D.query_path(params, result)
	return result.path
