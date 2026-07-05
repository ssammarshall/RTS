extends Node

enum COLLISION_LAYER {
	WORLD,
	UNIT,
	RESERVED,
	BUILDING,
	TERRAIN
}

# Scenes.

# Buildings.
# Production Buildings.
const MINE: PackedScene = preload("res://world/buildings/production/mine.tscn")

# UI.
const GROUP_CARD: PackedScene = preload("uid://bk2ukam6im5of")
const UNIT_CARD: PackedScene = preload("uid://cmvjcr2lua8ob")

# Shaders.
const BUILDING_PREVIEW: Shader = preload("res://world/buildings/building_preview.gdshader")

# Colors.
var GREEN_TRANSPARENT := Color("43e34366")
var RED_TRANSPARENT := Color("fa0d4e49")
var WHITE_TRANSPARENT := Color("ffffff49")
