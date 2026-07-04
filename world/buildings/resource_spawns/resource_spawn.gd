class_name ResourceSpawn extends Building

func _ready() -> void:
	super._ready()
	
	construction_complete = true # ResourceSpawns do not need to be constructed.

func extract() -> int:
	if resource.amount < 0: return 0
	
	resource.amount -= 1 # eventually update to have more than one type of resource
	return 1
