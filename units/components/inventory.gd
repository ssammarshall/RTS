class_name Inventory extends Resource

var equipped_item: Item
var resource: StrategicResource
var resource_limit: int = 10

func equip(item_data: ItemData, unit: Unit) -> void:
	var item := item_data.scene.instantiate() as Item
	if not item:
		printerr("Failed to instantiate item from scene: ", item_data.scene)
		return
	item.data = item_data
	item.durability = item_data.max_durability
	if equipped_item: unequip(unit)
	equipped_item = item
	unit.add_child(equipped_item)

func has_item(type: ItemData.Type) -> bool:
	if not equipped_item: return false
	elif equipped_item.get_item_type() == type: return true
	return false

func swap_resource_type(new_type: StrategicResource.Type) -> void:
	if resource and resource.type != new_type:
		resource.amount = 0
		resource.type = new_type
	elif not resource:
		resource = StrategicResource.new()
		resource.type = new_type

func unequip(unit: Unit) -> void:
	if equipped_item:
		unit.remove_child(equipped_item)
		equipped_item.queue_free()
		equipped_item = null

func use_item(unit: Unit) -> bool:
	if not equipped_item: return false
	
	var item_used := equipped_item.use()
	if equipped_item.durability <= 0: unequip(unit)
	
	if item_used: return true
	else: return false
