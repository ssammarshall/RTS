class_name ItemData extends Resource

enum Type {
	NONE,
	PICKAXE,
	AXE,
	SWORD,
	SHIELD,
	SPEAR
}
@export var type := ItemData.Type.NONE
@export var attack_damage: int = 1
@export var throw_damage: int = 1
@export var armor_class: int = 1
@export var max_durability: int = 100
@export var scene: PackedScene
