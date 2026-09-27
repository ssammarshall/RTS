extends Node

const WHEEL_SIZE := 64
const SKIP_CHECK_INTERVAL := 64
const QUEUE_COMPACT_AT := 1024

var budget_usec := 2000
var deferred_budget_usec := 1000

var tick := 0

var active_tasks := 0
var runs := 0
var late_runs := 0
var max_lateness := 0
var overrun_ticks := 0
var deferred_runs := 0
var busy_usec := 0

var _slot_tasks: Array[Array] = []
var _slot_dues: Array[Array] = []
var _late_tasks: Array = []
var _late_dues: Array = []
var _late_head := 0
var _deferred: Array[Callable] = []
var _deferred_head := 0
var _rng := RandomNumberGenerator.new()

var _step := 0.0
var _tps := 60
var _deadline := 0
var _over_budget := false

func _ready() -> void:
	process_physics_priority = -1000
	_rng.seed = 1
	for i in WHEEL_SIZE:
		_slot_tasks.append([])
		_slot_dues.append([])

func add(callback: Callable, interval: float) -> ThinkTask:
	var task := ThinkTask.new(callback, interval)
	task._last = tick
	active_tasks += 1
	if is_finite(interval):
		_schedule(task, tick + 1 + _rng.randi_range(0, _to_ticks(interval) - 1))
	return task

func remove(task: ThinkTask) -> void:
	if not task or not task._active: return
	task._active = false
	task._due = -1
	active_tasks -= 1

func wake(task: ThinkTask) -> void:
	if not task._active: return
	task._touched = true
	if task._due >= 0 and task._due <= tick + 1: return
	_schedule(task, tick + 1)

func schedule_in(task: ThinkTask, seconds: float) -> void:
	if not task._active: return
	task._touched = true
	if is_finite(seconds): _schedule(task, tick + _to_ticks(seconds))
	else: task._due = -1

func defer(callable: Callable) -> void:
	_deferred.append(callable)

func deferred_pending() -> int:
	return _deferred.size() - _deferred_head

func late_pending() -> int:
	return _late_tasks.size() - _late_head

func _to_ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * Engine.physics_ticks_per_second))

func _schedule(task: ThinkTask, due: int) -> void:
	task._due = due
	var slot := due % WHEEL_SIZE
	_slot_tasks[slot].append(task)
	_slot_dues[slot].append(due)

func _physics_process(delta: float) -> void:
	tick += 1
	_step = delta
	_tps = Engine.physics_ticks_per_second
	var start := Time.get_ticks_usec()
	_deadline = start + budget_usec
	_over_budget = false

	_run_late()

	var slot := tick % WHEEL_SIZE
	var tasks := _slot_tasks[slot]
	var dues := _slot_dues[slot]
	_slot_tasks[slot] = []
	_slot_dues[slot] = []
	if _over_budget:
		_late_tasks.append_array(tasks)
		_late_dues.append_array(dues)
	else:
		_run_slot(tasks, dues)

	if _over_budget: overrun_ticks += 1
	_run_deferred()
	busy_usec += Time.get_ticks_usec() - start

# The clock is read before every run but only every SKIP_CHECK_INTERVAL skipped entries.
# Consumed entries are nulled so removed tasks are freed as they're passed, not all at once on clear().
func _run_late() -> void:
	var skips := 0
	while _late_head < _late_tasks.size():
		var task: ThinkTask = _late_tasks[_late_head]
		var due: int = _late_dues[_late_head]
		if task._due == due and due <= tick:
			if Time.get_ticks_usec() >= _deadline:
				_over_budget = true
				break
			_late_tasks[_late_head] = null
			_late_head += 1
			_run(task, due)
			continue
		_late_tasks[_late_head] = null
		_late_head += 1
		if task._due == due: _schedule(task, due)
		skips += 1
		if skips % SKIP_CHECK_INTERVAL == 0 and Time.get_ticks_usec() >= _deadline:
			_over_budget = true
			break
	if _late_head >= _late_tasks.size():
		_late_tasks.clear()
		_late_dues.clear()
		_late_head = 0
	elif _late_head >= QUEUE_COMPACT_AT and _late_head * 2 >= _late_tasks.size():
		_late_tasks = _late_tasks.slice(_late_head)
		_late_dues = _late_dues.slice(_late_head)
		_late_head = 0

func _run_slot(tasks: Array, dues: Array) -> void:
	var skips := 0
	for i in tasks.size():
		var task: ThinkTask = tasks[i]
		var due: int = dues[i]
		if task._due != due or due > tick:
			if task._due == due: _schedule(task, due)
			skips += 1
			if skips % SKIP_CHECK_INTERVAL == 0 and Time.get_ticks_usec() >= _deadline:
				_carry_to_late(tasks, dues, i + 1)
				return
			continue
		if Time.get_ticks_usec() >= _deadline:
			_carry_to_late(tasks, dues, i)
			return
		_run(task, due)

func _carry_to_late(tasks: Array, dues: Array, from: int) -> void:
	_over_budget = true
	_late_tasks.append_array(tasks.slice(from))
	_late_dues.append_array(dues.slice(from))

func _run(task: ThinkTask, due: int) -> void:
	if not task.callback.is_valid():
		remove(task)
		return
	if due < tick:
		late_runs += 1
		max_lateness = maxi(max_lateness, tick - due)
	var elapsed := (tick - task._last) * _step
	task._last = tick
	task._due = -1
	task._touched = false
	runs += 1
	task.callback.call(elapsed)
	if task._active and not task._touched and is_finite(task.interval):
		_schedule(task, tick + maxi(1, roundi(task.interval * _tps)))

func _run_deferred() -> void:
	if _deferred_head >= _deferred.size(): return
	var deadline := Time.get_ticks_usec() + deferred_budget_usec
	while _deferred_head < _deferred.size():
		var callable := _deferred[_deferred_head]
		_deferred_head += 1
		if callable.is_valid():
			callable.call()
			deferred_runs += 1
		if Time.get_ticks_usec() >= deadline: break
	if _deferred_head >= _deferred.size():
		_deferred.clear()
		_deferred_head = 0
	elif _deferred_head >= QUEUE_COMPACT_AT and _deferred_head * 2 >= _deferred.size():
		_deferred = _deferred.slice(_deferred_head)
		_deferred_head = 0
