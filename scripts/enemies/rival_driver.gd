extends "res://scripts/vehicles/player_vehicle_input.gd"
## Only supplies commands. The shared rigid-body controller does all movement.
@export var target: RigidBody3D
@export var patrol_points: PackedVector3Array = PackedVector3Array([Vector3(28, 0, -28), Vector3(28, 0, 28), Vector3(-28, 0, 28), Vector3(-28, 0, -28)])
@export_range(5.0, 100.0) var engagement_range: float = 60.0
@export_range(1.0, 30.0) var desired_speed: float = 14.0
@export_range(5.0, 25.0) var following_distance: float = 10.0
@export_range(5.0, 80.0) var firing_range: float = 35.0
@export_range(1.0, 30.0) var aim_tolerance_degrees: float = 9.0
@export_range(0.1, 3.0) var fire_cadence: float = 0.8
@export_range(2.0, 15.0) var obstacle_lookahead: float = 7.0
@export_range(0.5, 10.0) var stuck_delay: float = 2.0
@export_range(0.5, 5.0) var reverse_duration: float = 1.6
@export_range(1.0, 10.0) var rollover_delay: float = 4.0
@export_range(2, 6) var attempts_before_reset: int = 3
@onready var vehicle: RigidBody3D = get_parent()
@onready var weapon = vehicle.get_node("Blaster")
@onready var health = vehicle.get_node("DamageReceiver")
var state: String = "PATROL"
var waypoint: int = 0
var stuck_time: float = 0.0
var rollover_time: float = 0.0
var reverse_remaining: float = 0.0
var recovery_attempts: int = 0
var reset_count: int = 0
var recovery_origin: Vector3
var has_line_of_sight: bool = false
var recovery_turn: float = 1.0

func _ready() -> void:
	weapon.fire_rate = fire_cadence
	health.respawned.connect(reset_navigation)
	recovery_origin = vehicle.global_position

func reset_navigation() -> void:
	clear_commands()
	reset_requested = false
	weapon.cooldown = 0.0
	state = "PATROL"
	waypoint = 0
	stuck_time = 0.0
	rollover_time = 0.0
	reverse_remaining = 0.0
	recovery_attempts = 0
	has_line_of_sight = false
	recovery_origin = vehicle.global_position

func _physics_process(delta: float) -> void:
	clear_commands()
	if not controls_enabled:
		state = "DESTROYED"
		return
	if reset_requested:
		state = "WAITING FOR SAFE RESET"
		return
	rollover_time = rollover_time + delta if vehicle.global_basis.y.dot(Vector3.UP) < 0.3 else 0.0
	if rollover_time >= rollover_delay:
		_request_recovery_reset()
		return
	if reverse_remaining > 0.0:
		state = "RECOVERING"
		reverse_remaining -= delta
		brake = 0.75
		steering = -recovery_turn
		return
	var goal := vehicle.global_position
	state = "PATROL"
	has_line_of_sight = false
	var target_alive := false
	if is_instance_valid(target):
		var target_health = target.get_node("DamageReceiver")
		target_alive = not target_health.is_destroyed and target_health.protection_remaining <= 0.0
		if target_alive and vehicle.global_position.distance_to(target.global_position) <= engagement_range:
			has_line_of_sight = _can_see_target()
			if has_line_of_sight:
				state = "PURSUIT"
				goal = target.global_position
	if state == "PATROL":
		if patrol_points.is_empty():
			return
		goal = patrol_points[waypoint % patrol_points.size()]
		if vehicle.global_position.slide(Vector3.UP).distance_to(goal.slide(Vector3.UP)) < 6.0:
			waypoint = (waypoint + 1) % patrol_points.size()
			goal = patrol_points[waypoint]
	var local_goal: Vector3 = vehicle.global_basis.inverse() * (goal - vehicle.global_position)
	var angle := atan2(local_goal.x, -local_goal.z)
	steering = clampf(angle / 0.6, -1.0, 1.0)
	var speed_goal := desired_speed * lerpf(1.0, 0.25, clampf(absf(angle) / 1.5, 0.0, 1.0))
	var distance := vehicle.global_position.distance_to(goal)
	if state == "PURSUIT":
		speed_goal *= clampf((distance - following_distance) / 12.0, 0.0, 1.0)
		# Back away to regain turning room rather than orbiting at point-blank range.
		if distance < following_distance and absf(angle) > deg_to_rad(aim_tolerance_degrees):
			recovery_turn = steering
			reverse_remaining = reverse_duration
			state = "RECOVERING"
			brake = 0.75
			steering = -recovery_turn
			return
		fire_requested = distance <= firing_range and absf(angle) <= deg_to_rad(aim_tolerance_degrees) and has_line_of_sight and health.protection_remaining <= 0.0
	var avoid := _obstacle_steering()
	if absf(avoid) > 0.0:
		steering = avoid
		speed_goal = minf(speed_goal, 4.0)
	var speed: float = vehicle.linear_velocity.dot(-vehicle.global_basis.z)
	throttle = clampf((speed_goal - speed) / 4.0, 0.0, 1.0)
	if speed > speed_goal + 0.8:
		brake = clampf((speed - speed_goal) / 6.0, 0.0, 0.8)
	if vehicle.global_position.distance_to(recovery_origin) > 5.0:
		recovery_attempts = 0
	stuck_time = stuck_time + delta if throttle > 0.2 and vehicle.linear_velocity.length() < 0.8 else 0.0
	if stuck_time >= stuck_delay:
		recovery_attempts += 1
		stuck_time = 0.0
		recovery_origin = vehicle.global_position
		if recovery_attempts >= attempts_before_reset:
			_request_recovery_reset()
		else:
			recovery_turn = steering if absf(steering) > 0.2 else 1.0
			reverse_remaining = reverse_duration

func _request_recovery_reset() -> void:
	clear_commands()
	reset_requested = true
	reset_count += 1
	rollover_time = 0.0
	recovery_attempts = 0
	reverse_remaining = 0.0
	stuck_time = 0.0
	state = "WAITING FOR SAFE RESET"

func _can_see_target() -> bool:
	var query := PhysicsRayQueryParameters3D.create(weapon.muzzle.global_position, target.global_position + Vector3.UP * 0.1, 3, [vehicle.get_rid()])
	query.hit_from_inside = true
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target

func _obstacle_steering() -> float:
	var distances: Array[float] = []
	for side in [-1.0, 0.0, 1.0]:
		var start: Vector3 = vehicle.global_position + vehicle.global_basis * Vector3(side * 0.75, 0.1, -2.2)
		var direction: Vector3 = (-vehicle.global_basis.z + vehicle.global_basis.x * side * 0.65).normalized()
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * obstacle_lookahead, 3, [vehicle.get_rid()])
		query.hit_from_inside = true
		var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
		distances.append(start.distance_to(hit.position) if not hit.is_empty() else obstacle_lookahead)
	if distances[1] < obstacle_lookahead * 0.8:
		return 1.0 if distances[2] >= distances[0] else -1.0
	return 0.0
