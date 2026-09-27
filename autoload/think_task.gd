class_name ThinkTask extends RefCounted

var callback: Callable
var interval: float # INF: only runs when woken or rescheduled.

var _due := -1
var _last := 0
var _active := true
var _touched := false

func _init(task_callback: Callable, task_interval: float) -> void:
	callback = task_callback
	interval = task_interval

func is_active() -> bool:
	return _active

func is_scheduled() -> bool:
	return _due >= 0
