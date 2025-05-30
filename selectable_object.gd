class_name SelectableObject extends Node3D

# Nodes.
@export var highlight: Node3D

# Selection variables.
var is_selected: bool = false:
	set(value):
		is_selected = value
		if is_selected: highlight.show()
		else: highlight.hide()
