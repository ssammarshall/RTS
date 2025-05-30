class_name StrategicResource extends Resource

enum Type {
	Food,
	Wood,
	Gold,
	Stone
}
@export var type: Type

var type_name: Array[String] = ["Food", "Wood", "Gold", "Stone"]

@export_range(0, 1000, 1) var amount: int = 0
