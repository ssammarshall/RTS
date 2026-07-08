class_name Gatherer extends UnitRole

func _ready()->void:
	super._ready()
	
	schedule.append(UnitCommand.new()) # TEMP
