class_name Item extends Node3D
# An item that can be equipped and/or used by a unit.

var data: ItemData
var durability: int

func use() -> bool:
	if durability <= 0: return false
	durability -= 1
	return true
