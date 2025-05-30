extends Node

# Buildings.
signal set_build_mode(value: bool)
signal start_building_placement(user: User, building: Building)
signal building_selected(building: Building)
signal building_placed(buildilng: Building)
signal building_constructed(building: Building)
signal building_remove_last

# Selection.
signal unit_focus(unit: Unit)
