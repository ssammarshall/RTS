class_name UnitController extends RefCounted
# Drives a unit's RigidBody3D toward a desired horizontal velocity and facing. The velocity change per step is capped
# by an acceleration (braking when stopping), so it doesn't overshoot the way pushing a force and clamping can.
# AI units call next_velocity and yaw_rate from the act loop; a player-controlled unit can call integrate from
# _integrate_forces.

var max_speed := 10.0
var acceleration := 80.0
var braking := 120.0
var air_control := 0.0
var turn_speed := 12.0

var desired_velocity := Vector3.ZERO
var desired_yaw := 0.0

func next_velocity(current: Vector3, grounded: bool, delta: float) -> Vector3:
	var horizontal := Vector3(current.x, 0.0, current.z)
	var target := Vector3(desired_velocity.x, 0.0, desired_velocity.z).limit_length(max_speed)
	var rate := acceleration if target != Vector3.ZERO else braking
	if not grounded: rate *= air_control
	horizontal = horizontal.move_toward(target, rate * delta)
	return Vector3(horizontal.x, current.y, horizontal.z)

func yaw_rate(current_yaw: float) -> float:
	return wrapf(desired_yaw - current_yaw, -PI, PI) * turn_speed

func integrate(state: PhysicsDirectBodyState3D, grounded: bool) -> void:
	state.linear_velocity = next_velocity(state.linear_velocity, grounded, state.step)
	state.angular_velocity = Vector3(0.0, yaw_rate(state.transform.basis.get_euler().y), 0.0)
