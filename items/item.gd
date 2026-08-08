class_name Item extends Node3D
# An item that can be equipped and/or used by a unit.

var data: ItemData
var durability: int

func get_item_type() -> ItemData.Type:
	return data.type if data else ItemData.Type.NONE

func use() -> bool:
	if durability <= 0: return false
	durability -= 1
	return true
