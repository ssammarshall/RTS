class_name GUI extends CanvasLayer

var user: User

# Nodes.
@export var available_units: AvailableUnitsContainer
@export var select_info: SelectInfoContainer
@export var building_panel: BuildingPanel

@onready var fps_label = $FPSLabel

var selected_objects: Array[SelectableObject]

func _ready() -> void:
	await owner.ready
	
	user = owner as User
	assert(user != null)
	
	user.clear_all_selected.connect(Callable(_on_clear_all_selected))
	
	available_units.user = user
	
	select_info.hide()
	SignalBus.building_selected.connect(Callable(_on_building_selected))
	
	building_panel.user = user
	building_panel.hide()
	SignalBus.set_build_mode.connect(Callable(_on_set_build_mode))
	
	match user.current_mode:
		user.MODE.RTS:
			for i in user.control_groups.size():
				available_units.load_group(user.control_groups[i])

func _physics_process(_delta: float) -> void:
	fps_label.set_text("FPS: %d" % Engine.get_frames_per_second())

func _on_clear_all_selected() -> void:
	for object in selected_objects:
		object.is_selected = false
	selected_objects.clear()
	
	select_info.selected_building = null

func _on_building_selected(building: Building) -> void:
	selected_objects.append(building.selectable_object)
	building.select(true)
	
	if not select_info.visible:
		select_info.show()
	select_info.selected_building = building

func _on_set_build_mode(value: bool) -> void:
	building_panel.visible = value
