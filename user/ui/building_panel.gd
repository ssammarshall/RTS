class_name BuildingPanel extends PanelContainer

@export var button: Button

var user: User

func _ready() -> void:
	button.pressed.connect(Callable(_on_button_pressed))

func _on_button_pressed() -> void:
	# TEST
	var building = Global.MINE.instantiate() as Building
	
	SignalBus.start_building_placement.emit(user, building)
