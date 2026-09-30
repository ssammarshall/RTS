class_name Item extends Node3D
# An item that can be equipped and/or used by a unit.

var data: ItemData
var durability: int

func get_item_type() -> ItemData.Type:
	return data.type if data else ItemData.Type.NONE

# Uses the item up to `times` times; returns how many uses its durability allowed.
func use(times := 1) -> int:
	var used := clampi(durability, 0, times)
	durability -= used
	return used
