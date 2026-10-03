class_name Faction extends Resource
# A faction or subfaction as data. Which faction a unit belongs to is on the unit (Unit.faction), so it can change.

@export var title := ""
@export var parent: Faction # Set for a subfaction.
@export var color := Color.WHITE
@export var roster: Array[UnitType] = []
