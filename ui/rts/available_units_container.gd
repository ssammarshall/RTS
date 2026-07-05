class_name AvailableUnitsContainer extends Control

@export var background: HBoxContainer # Doesn't do anything...

var user: User:
	set(value):
		user = value
		user.control_group_set.connect(Callable(_set_control_group))

var group_cards: Array[GroupCard]
var unit_cards: Array[UnitCard]
var num_of_units: int = 0
var selected_card: UnitCard:
	set(new_card):
		selected_card = new_card
		double_click_timer.start(double_click_window_time)
		is_double_click = true

var double_click_timer := Timer.new()
var double_click_window_time: float = 1.0
var is_double_click := false

func _ready() -> void:
	double_click_timer.set_one_shot(false)
	double_click_timer.timeout.connect(Callable(_on_double_click_timer_timeout))
	add_child(double_click_timer)

func _on_double_click_timer_timeout() -> void:
	is_double_click = false

func load_group(group: Group) -> void:
	var new_card := group.create_group_card()
	new_card.card_selected.connect(Callable(_on_card_selected))
	
	group_cards.append(new_card)
	add_child(new_card)
	
	var group_size: int = group.size()
	if group_size <= 0:
		new_card.visible = false
	else:
		num_of_units += group_size
		for i in group_size:
			unit_cards.append(new_card.unit_cards[i])

func _on_card_selected(new_card: UnitCard) -> void:
	if new_card == null: return
	
	if not selected_card:
		selected_card = new_card
		if not user.hold_group: user.clear_selected()
		user.rts_controller.rts_select.select_unit(user, selected_card.unit)
		return
	
	# ADD DOUBLE CLICK TIMER TIME CHECK HERE
	# IF TIME > 0 THEN DOUBLE CLICK CONFIRMED
	elif new_card == selected_card:
		if selected_card.is_selected:
			if is_double_click:
				SignalBus.unit_focus.emit(selected_card.unit)
				return
			elif not user.hold_group:
				user.clear_selected()
				user.rts_controller.rts_select.select_unit(user, selected_card.unit)
				selected_card = new_card
				return
			user.rts_controller.rts_select.deselect_unit(user, selected_card.unit)
			selected_card = null
			return
	
	if not user.hold_group:
		user.clear_selected()
	elif new_card.is_selected: # If User is holding group and clicks to select already selected Unit.
		user.rts_controller.rts_select.deselect_unit(user, new_card.unit)
		return
	
	if selected_card.is_selected and user.shift:
		var selected_index: int = unit_cards.find(selected_card)
		var new_index: int = unit_cards.find(new_card)
		if selected_index > new_index:
			shift_select(new_index, selected_index)
		else:
			shift_select(selected_index, new_index)
		return
	
	# When User has a Unit selected but selects another Unit without user.hold_group
	selected_card = new_card
	user.rts_controller.rts_select.select_unit(user, selected_card.unit)

# Select Units inbetween two UnitCards in unit_cards array.
func shift_select(start: int, end: int) -> void:
	var x: int = start
	while x != -1:
		user.rts_controller.rts_select.select_unit(user, unit_cards[x].unit)
		if x != end:x += 1
		else:x = -1

func _set_control_group(num: int) -> void:
	if not group_cards[num].visible:
		group_cards[num].visible = true
	
	var control_group: Group = user.control_groups[num]
	var control_group_card: GroupCard = group_cards[num]
	for group_card in group_cards:
		var i: int = 0
		var swapped_cards: Array[UnitCard] = [] # Keep track of cards that need to be swapped.
		for unit_card in group_card.unit_cards:
			if control_group.has(unit_card.unit):
				swapped_cards.append(unit_card) # This unit_card needs to swap group_cards.
				unit_card.index = control_group_card.group_number + control_group_card.unit_cards.size()
			else:
				unit_card.index = group_card.group_number + i
				i += 1
		
		if swapped_cards.size() > 0:
			for card in swapped_cards:
				group_card.remove_unit(card) # Remove each card from their original GroupCard.
				control_group_card.add_unit(card) # Add each card to control_group_card.
	
	unit_cards.clear()
	for group_card in group_cards:
		if group_card.unit_cards.size() < 1 and group_card.visible:
			group_card.visible = false
		else:
			for unit_card in group_card.unit_cards:
				unit_cards.append(unit_card)
