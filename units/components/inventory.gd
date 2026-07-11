class_name Inventory extends Resource

var equipped_item: Item
var resource: StrategicResource
var resource_limit: int = 10

func swap_resource_type(new_type: StrategicResource.Type) -> void:
	if resource and resource.type != new_type:
		resource.amount = 0
		resource.type = new_type
	elif not resource:
		resource = StrategicResource.new()
		resource.type = new_type
