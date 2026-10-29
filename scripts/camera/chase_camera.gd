extends Camera3D
@export var target: Node3D
@export var distance: float = 8.5
@export var height: float = 4.0
@export var rotation_response: float = 4.0
@export var smoothing: float = 9.0
var heading := Vector3.BACK
var initialized: bool = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var back := target.global_basis.z.slide(Vector3.UP).normalized()
	if back.length_squared() > 0.1:
		heading = heading.slerp(back, 1.0 - exp(-rotation_response * delta)).normalized()
	var focus := target.global_position + Vector3.UP * 0.8
	var desired := focus + heading * distance + Vector3.UP * height
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.4
	if not initialized or global_position.distance_to(desired) > 25.0:
		global_position = desired
		initialized = true
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
	look_at(focus)
