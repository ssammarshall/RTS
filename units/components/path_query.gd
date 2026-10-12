class_name PathQuery extends RefCounted
# A path query searches only the tiles around its leg, with no limit on the polygons it searches. A path that ends short
# of the target's closest point went around outside those tiles, so the whole map is searched instead.
# Queries requested during a tick run together on worker threads, and their paths are handed back the next tick.

const SHORT := 1.0
const TASKS := 4
const QUERIES_PER_TASK := 128

static var fallbacks := 0
static var _pending: Array[PathQuery] = []
static var _running: Array[PathQuery] = []
static var _group := -1

var path := PackedVector3Array()
var iteration := 0
var fell_back := false

var _on_done: Callable
var _params := NavigationPathQueryParameters3D.new()
var _result := NavigationPathQueryResult3D.new()
var _around: Array[RID]

# `on_done` gets the query back on the main thread, at the earliest the tick after.
static func request(from: Vector3, to: Vector3, on_done: Callable) -> PathQuery:
	var query := PathQuery.new(from, to, on_done)
	_pending.append(query)
	return query

# Once per tick, after the thinks: hands back the last batch's paths if it has finished, then sends out the requests
# made since. It never waits for the batch.
static func flush() -> void:
	if _group >= 0:
		if not WorkerThreadPool.is_group_task_completed(_group): return
		WorkerThreadPool.wait_for_group_task_completion(_group)
		_group = -1
		var done := _running
		_running = []
		for query in done:
			if query.fell_back: fallbacks += 1
			if query._on_done.is_valid(): query._on_done.call(query)
	if _pending.is_empty(): return
	var batch := _pending
	_pending = []
	_running = batch
	# Every thread running queries slows the main thread, so a small batch gets one.
	var tasks := mini(TASKS, ceili(batch.size() / float(QUERIES_PER_TASK)))
	_group = WorkerThreadPool.add_group_task(func(i: int) -> void: batch[i]._run(), batch.size(), tasks, false, "PathQuery")

static func pending() -> int:
	return _pending.size() + _running.size()

# Waits for the batch in flight, before the navigation map goes away.
static func finish() -> void:
	if _group < 0: return
	WorkerThreadPool.wait_for_group_task_completion(_group)
	_group = -1
	_running = []

func _init(from: Vector3, to: Vector3, on_done: Callable) -> void:
	var grid := Map.current.nav_grid
	_on_done = on_done
	_params.map = grid.nav_map
	_params.start_position = from
	_params.target_position = to
	_params.path_search_max_polygons = 0
	_params.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_NONE
	_params.included_regions = grid.regions_between(from, to)
	_around = grid.regions_around(to)
	iteration = NavigationServer3D.map_get_iteration_id(_params.map)

# Runs on a worker thread, so it touches only the navigation server and this query.
func _run() -> void:
	NavigationServer3D.query_path(_params, _result)
	path = _result.path
	if path.is_empty(): return
	var to := _params.target_position
	var gap := path[path.size() - 1].distance_to(to)
	if gap <= SHORT or gap <= NavGrid.closest_on(_around, to).distance_to(to) + SHORT: return
	fell_back = true
	_params.included_regions = []
	NavigationServer3D.query_path(_params, _result)
	path = _result.path
