extends Node
# Utility functions.

# CONSTANTS
const RAY_LENGTH: float = 1000
const SCREEN_MARGIN: int = 16

# Return 3d position of mouse.
func mouse_raycast_3d_position(camera: Camera3D, mouse_pos: Vector2, mask: int = 1) -> Vector3:
	var result:Dictionary = mouse_raycast(camera, mouse_pos, mask)
	
	if result.has("position"):return result["position"]
	else:return Vector3.ZERO

# Returns collision from raycast.
func mouse_raycast_collider(camera: Camera3D, mouse_pos: Vector2, mask: int = 1) -> Object:
	var result: Dictionary = mouse_raycast(camera, mouse_pos, mask)
	
	if result.has("collider"):return result["collider"]
	else:return null

# Return dictionary of raycast intersection from mouse position.
func mouse_raycast(camera: Camera3D, mouse_pos: Vector2, mask: int = 1) -> Dictionary:
	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	ray_query.collision_mask = mask
	
	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().get_direct_space_state()
	var result: Dictionary = space_state.intersect_ray(ray_query)
	if result: return result
	else: return {}

# Check mouse position and warp mouse to opposite side of screen when going at screen edge.
func check_mouse_margins(view: Viewport, current_mouse_pos: Vector2) -> void:
	var viewport_visible_rectangle: Rect2i = Rect2i(view.get_visible_rect())
	var viewport_size: Vector2i = viewport_visible_rectangle.size
	
	var new_mouse_pos: Vector2 = Vector2.ZERO
	new_mouse_pos.y = current_mouse_pos.y
	
	# Check if mouse x position is on edge of screen.
	if current_mouse_pos.x < SCREEN_MARGIN:
		new_mouse_pos.x = viewport_size.x - SCREEN_MARGIN
	elif current_mouse_pos.x > viewport_size.x - SCREEN_MARGIN:
		new_mouse_pos.x = SCREEN_MARGIN
	else:
		new_mouse_pos.x = current_mouse_pos.x
	
	# Check if mouse y position is on edge of screen.
	#if current_mouse_pos.y < margin:                                               # Took this out because it was causing camera rotation to glitch when moving mouse downwards.
		#new_mouse_pos.y = viewport_size.y - margin
	#elif current_mouse_pos.y > viewport_size.y - margin:
		#new_mouse_pos.y = margin
	#else:
		#new_mouse_pos.y = current_mouse_pos.y
	
	
	if current_mouse_pos == new_mouse_pos: return
	
	# If mouse is going off screen then warp mouse to opposite side.
	else: Input.warp_mouse(new_mouse_pos)
