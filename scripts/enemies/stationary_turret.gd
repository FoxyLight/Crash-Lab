extends "res://scripts/targets/target_dummy.gd"
## Reuses the target's health/respawn lifecycle; only the head rotates.
@export var target: Node3D
@export_range(5.0, 60.0) var detection_range: float = 38.0
@export_range(0.2, 3.0) var warning_time: float = 1.0
@export_range(0.2, 10.0) var aim_response: float = 3.0
var fire_requested: bool = false
var lock_time: float = 0.0
var has_line_of_sight: bool = false
@onready var head: Node3D = $Head
@onready var weapon = $Head/Blaster

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	fire_requested = false
	has_line_of_sight = false
	if is_destroyed or not is_instance_valid(target):
		lock_time = 0.0
		return
	var target_health = target.get_node_or_null("DamageReceiver")
	if target_health != null and (target_health.is_destroyed or target_health.protection_remaining > 0.0):
		lock_time = 0.0
		return
	var aim_point := target.global_position + Vector3.UP * 0.15
	if global_position.distance_to(aim_point) > detection_range:
		lock_time = 0.0
		return
	var direction := aim_point - head.global_position
	if direction.length_squared() < 0.01:
		lock_time = 0.0
		return
	var aim_up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
	var desired := Basis.looking_at(direction.normalized(), aim_up)
	head.global_basis = head.global_basis.slerp(desired, 1.0 - exp(-aim_response * delta)).orthonormalized()
	var query := PhysicsRayQueryParameters3D.create(weapon.muzzle.global_position, aim_point, 3, [get_rid()])
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	has_line_of_sight = not hit.is_empty() and hit.collider == target
	var aligned: bool = (-head.global_basis.z).dot(direction.normalized()) > 0.995
	if has_line_of_sight and aligned:
		lock_time += delta
		fire_requested = lock_time >= warning_time
	else:
		lock_time = 0.0
	_update_display()

func _update_display() -> void:
	super._update_display()
	label.text = label.text.replace("TARGET", "ENEMY TURRET")
	if not is_destroyed:
		label.text += "\n" + ("FIRING — DODGE!" if fire_requested else ("LOCKING..." if lock_time > 0.0 else "RANGE %dm" % detection_range))
	if is_instance_valid(head):
		head.visible = not is_destroyed
