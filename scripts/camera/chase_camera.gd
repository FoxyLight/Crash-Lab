extends Camera3D
@export var target: Node3D
@export var distance: float = 8.5
@export var height: float = 4.0
@export var rotation_response: float = 4.0
@export var smoothing: float = 9.0
var heading := Vector3.BACK
var initialized: bool = false
@export_range(0.0, 0.5) var moderate_shake: float = 0.06 # camera offset in meters
@export_range(0.0, 0.5) var major_shake: float = 0.18
var shake_remaining: float = 0.0
var shake_strength: float = 0.0
var shake_duration: float = 0.0

func _ready() -> void:
	if is_instance_valid(target):
		var health = target.get_node_or_null("DamageReceiver")
		if health != null:
			health.destroyed.connect(clear_impact)
			health.respawned.connect(clear_impact)

func clear_impact() -> void:
	shake_remaining = 0.0
	shake_strength = 0.0
	h_offset = 0.0
	v_offset = 0.0

func add_impact(data: Dictionary) -> void:
	if data.vehicle != target and data.collider != target:
		return
	if data.severity < 2:
		return
	shake_strength = clampf(major_shake if data.severity == 3 else moderate_shake, 0.0, 0.3)
	shake_duration = 0.32 if data.severity == 3 else 0.18
	shake_remaining = shake_duration

func _physics_process(delta: float) -> void:
	if is_instance_valid(target) and target.get_node("ImpactDetector").grace_remaining > 0.0:
		clear_impact()
	shake_remaining = maxf(0.0, shake_remaining - delta)
	var envelope := shake_remaining / maxf(0.01, shake_duration)
	var phase := (shake_duration - shake_remaining) * 85.0
	h_offset = sin(phase) * shake_strength * envelope
	v_offset = cos(phase * 1.3) * shake_strength * envelope * 0.6
	if not is_instance_valid(target):
		return
	var back := target.global_basis.z.slide(Vector3.UP).normalized()
	if back.length_squared() > 0.1:
		# Same planar smoothing, without slerp's unstable axis near parallel headings.
		var yaw := lerp_angle(atan2(heading.x, heading.z), atan2(back.x, back.z), 1.0 - exp(-rotation_response * delta))
		heading = Vector3(sin(yaw), 0.0, cos(yaw))
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
