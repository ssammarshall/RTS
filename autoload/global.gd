extends Node

# Scenes.

# Buildings.
# Production Buildings.
const MINE: PackedScene = preload("res://world/buildings/production/mine.tscn")

# UI.
const GROUP_CARD: PackedScene = preload("res://user/ui/group_card.tscn")
const UNIT_CARD: PackedScene = preload("res://user/ui/unit_card.tscn")

# Shaders.
const BUILDING_PREVIEW: Shader = preload("res://world/buildings/building_preview.gdshader")

# Colors.
var GREEN_TRANSPARENT := Color("43e34366")
var RED_TRANSPARENT := Color("fa0d4e49")
var WHITE_TRANSPARENT := Color("ffffff49")
