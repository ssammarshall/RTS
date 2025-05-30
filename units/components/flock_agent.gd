class_name FlockAgent extends Node3D

var unit: Unit

@export var enabled := true

@export var alginment_weight: float = 0.4
@export var cohesion_weight: float = 0.2
@export var separation_weight: float = 0.2
@export var neighbor_radius: float = 3.0

var max_speed: float = 3.0
var min_speed: float = 1.0

var max_acceleration: float = 0.2

var alignment: Vector3 = Vector3.ZERO
var cohesion: Vector3 = Vector3.ZERO
var separation: Vector3 = Vector3.ZERO
var neighbor_count: int = 0

var neighbors: Array[Unit]
var velocity := Vector3.ZERO

func _ready() -> void:
	await owner.ready
	
	unit = owner as Unit
	assert(owner != null)

# Called during physics_update of Unit.
func physics_update(_delta: float) -> void:
	if !enabled: return
	
	alignment = Vector3.ZERO
	cohesion = Vector3.ZERO
	separation = Vector3.ZERO
	neighbor_count = 0
	
	for neighbor in neighbors:
		var dist:float = unit.global_position.distance_to(neighbor.global_position)
		alignment += neighbor.velocity
		cohesion += neighbor.global_position
		separation += (unit.global_position - neighbor.global_position) / dist
		neighbor_count += 1
	
	if neighbor_count > 0:
		calc_alignment()
		calc_cohesion()
		calc_separation()
	
	unit.velocity += alignment*alginment_weight + cohesion*cohesion_weight + separation*separation_weight
	#print(unit.velocity)

func calc_alignment() -> void:
	alignment = alignment / neighbor_count
	alignment = alignment.normalized() * max_speed - unit.velocity

func calc_cohesion() -> void:
	cohesion = (cohesion / neighbor_count) - unit.global_position
	cohesion = cohesion.normalized() * max_speed - unit.velocity

func calc_separation() -> void:
	separation = separation / neighbor_count
	if separation.length() > 0:
		separation = separation.normalized() * max_speed - unit.velocity

func _on_area_3d_body_entered(body: Node3D) -> void:
	if !enabled:return
	if body is Unit:neighbors.append(body)

func _on_area_3d_body_exited(body: Node3D) -> void:
	if !enabled:return
	if body is Unit:neighbors.erase(body)
