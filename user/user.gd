class_name User extends Node3D

# Nodes.
@onready var gui: GUI = $GUI
@onready var dragbox: NinePatchRect = $Control/Dragbox
@onready var camera_rig: CameraRig = $CameraRig

enum MODE {
	RTS,
	UNIT_CONTROL
}
var current_mode: MODE = MODE.RTS:
	set(new_mode):
		match current_mode:
			MODE.RTS:
				pass
			MODE.UNIT_CONTROL:
				pass
		
		current_mode = new_mode
		match current_mode:
			MODE.RTS:
				camera_rig.current_mode = CameraRig.MODE.RTS
			MODE.UNIT_CONTROL:
				camera_rig.current_mode = CameraRig.MODE.UNIT_CONTROL

# Modules.
var rect := Rect2() # Used by multiple modules.
var rts_controller: RTSController # Input.

# Unit and Group variables.
signal clear_all_selected
signal control_group_set(num: int)
@export var available_units: Array[Unit]
var control_groups: Array[Group] # First control group is always the currently selected group.
var hold_group: bool = false # Controls whether or not selected objects should be held if holding shift or ctrl.

var mouse_global_position := Vector3.ZERO

# Settings.
@export var mouse_sens: float = 1.0

# Modifiers.
var shift: bool = false:
	set(value):
		shift = value
		camera_rig.shift = value
var ctrl: bool = false

func _ready() -> void:
	dragbox.visible = false
	
	rts_controller = RTSController.new(self)
	
	# Initialize control groups.
	# 
	# Control_group[0] is a temporary Group for currently selected Units.
	# All Units are added to control_group[0] when selected and removed when deselected.
	for num in 11:
		control_groups.append(Group.new(num))
	
	# Control_group[10] is a staging Group for all Units without a Group.
	# At start of game, all Units in available_units are placed in control_group[10].
	for unit in available_units:
		if unit.group_num < 0:
			control_groups[10].add_unit(unit)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _unhandled_input(event: InputEvent) -> void:
	match current_mode:
		MODE.RTS:
			rts_controller.handle_input(event)

func _process(delta: float) -> void:
	match current_mode:
		MODE.RTS:
			rts_controller.update(delta)

func _physics_process(_delta: float) -> void:
	pass

func set_mode(mode: MODE) -> void:
	current_mode = mode

func get_selected_group() -> Group:
	return control_groups[0]

func clear_selected() -> void:
	get_selected_group().empty_group()
	clear_all_selected.emit()

func set_control_group(num: int) -> void:
	if num <= 0:return
	for unit in get_selected_group().units:
		if unit.group_num > 0 and unit.group_num != num:control_groups[unit.group_num].remove_unit(unit)
		control_groups[num].add_unit(unit)
		unit.group_num = num
	control_group_set.emit(num)
