class_name SelectInfoContainer extends PanelContainer

@export var label: Label

var selected_building: Building:
	set(building):
		selected_building = building
		if selected_building == null:
			text = " \n "
			hide()

var text: String:
	set(new_text):
		text = new_text
		label.text = text

func _ready() -> void:
	text = ""

func _process(_delta: float) -> void:
	if selected_building: display_building_info(selected_building)

func display_building_info(building: Building) -> void:
	text = building.title
	
	var resource: StrategicResource = building.resource
	if resource:
		text += "\n" + str(resource.amount) + " / " + str(building.resource_limit)
