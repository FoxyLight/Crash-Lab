extends RigidBody3D
@export var body_color: Color = Color("d85828")
## Forces act at four tire contacts; only recovery replaces the body transform.
@export_group("Powertrain")
@export var engine_force: float = 15000.0
@export var brake_force: float = 24000.0
@export var maximum_speed: float = 42.0 # m/s, about 151 km/h
@export var reverse_speed: float = 13.0
@export_group("Handling")
@export var steering_angle: float = 0.52
@export var high_speed_steering_angle: float = 0.20
@export var steering_response: float = 6.0
@export var lateral_traction: float = 8.0
@export_range(0.05, 1.0) var handbrake_grip: float = 0.22
@export var tire_force_limit: float = 10000.0
@export_group("Chassis")
@export var vehicle_mass: float = 1400.0
@export var chassis_linear_damping: float = 0.12
@export var chassis_angular_damping: float = 1.8
@export var suspension_length: float = 0.65
@export var spring_stiffness: float = 36000.0
@export var spring_damping: float = 4200.0
@export var wheel_radius: float = 0.32
@export_group("Recovery")
@export var reset_height: float = 1.25
@export var fall_reset_height: float = -12.0

@onready var driver = $DriverInput
var grounded_wheels: int = 0
var signed_speed: float = 0.0
var current_steering: float = 0.0
var spawn_transform: Transform3D
var reset_generation: int = 0
var wheel_mounts: Array[Vector3] = [Vector3(-0.88, 0, -1.35), Vector3(0.88, 0, -1.35), Vector3(-0.88, 0, 1.25), Vector3(0.88, 0, 1.25)]
var wheels: Array[Node3D] = []
var wheel_lengths: Array[float] = [0.65, 0.65, 0.65, 0.65]

func is_spawn_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = $CollisionShape3D.shape
	query.transform = spawn_transform
	query.transform.origin.y = reset_height
	query.margin = 0.3
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _ready() -> void:
	mass = vehicle_mass
	linear_damp = chassis_linear_damping
	angular_damp = chassis_angular_damping
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0.1)
	spawn_transform = global_transform
	_build_visuals()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if (driver.reset_requested or state.transform.origin.y < fall_reset_height) and is_spawn_clear():
		driver.reset_requested = false
		var recovery := spawn_transform
		recovery.origin.y = reset_height
		state.transform = recovery
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		current_steering = 0.0
		reset_generation += 1
		return
	var basis := state.transform.basis
	var forward := -basis.z
	signed_speed = state.linear_velocity.dot(forward)
	var speed_ratio := clampf(absf(signed_speed) / maximum_speed, 0.0, 1.0)
	var angle := lerpf(steering_angle, high_speed_steering_angle, speed_ratio)
	current_steering = move_toward(current_steering, -driver.steering * angle, steering_response * state.step)
	grounded_wheels = 0
	for i in wheel_mounts.size():
		var mount := state.transform * wheel_mounts[i]
		var query := PhysicsRayQueryParameters3D.create(mount, mount - basis.y * (suspension_length + wheel_radius + 0.25), 1, [get_rid()])
		var hit := state.get_space_state().intersect_ray(query)
		wheel_lengths[i] = suspension_length
		if hit.is_empty() or hit.normal.dot(basis.y) < 0.35:
			continue
		var length_now: float = mount.distance_to(hit.position) - wheel_radius
		wheel_lengths[i] = clampf(length_now, 0.05, suspension_length)
		if length_now > suspension_length:
			continue
		grounded_wheels += 1
		var offset: Vector3 = hit.position - state.transform.origin
		var velocity := state.linear_velocity + state.angular_velocity.cross(offset - basis * center_of_mass)
		var compression := suspension_length - length_now
		var spring := clampf(compression * spring_stiffness - velocity.dot(basis.y) * spring_damping, 0.0, vehicle_mass * 9.8 * 2.0)
		state.apply_force(basis.y * spring, mount - state.transform.origin)
		var tire_forward := forward.rotated(basis.y, current_steering if i < 2 else 0.0)
		tire_forward = tire_forward.slide(hit.normal).normalized()
		var tire_right := tire_forward.cross(hit.normal).normalized()
		var grip: float = handbrake_grip if driver.handbrake and i >= 2 else 1.0
		var lateral := clampf(-velocity.dot(tire_right) * lateral_traction * vehicle_mass / 4.0 * grip, -tire_force_limit * grip, tire_force_limit * grip)
		var drive := 0.0
		if driver.throttle > 0.0:
			drive += driver.throttle * (brake_force if signed_speed < -0.8 else engine_force * (1.0 - speed_ratio * speed_ratio))
		if driver.brake > 0.0:
			drive -= driver.brake * (brake_force if signed_speed > 0.8 else engine_force * clampf(1.0 + signed_speed / reverse_speed, 0.0, 1.0))
		var longitudinal: float = drive / 4.0
		if driver.handbrake and i >= 2:
			longitudinal += clampf(-velocity.dot(tire_forward) * vehicle_mass / 4.0 / state.step, -brake_force / 2.0, brake_force / 2.0)
		# Limit the combined contact force to available suspension load.
		var tire_force := (tire_right * lateral + tire_forward * longitudinal).limit_length(spring * 1.8)
		state.apply_force(tire_force, offset)

func _process(_delta: float) -> void:
	for i in wheels.size():
		wheels[i].position = wheel_mounts[i] - Vector3.UP * wheel_lengths[i]
		wheels[i].rotation.y = current_steering if i < 2 else 0.0

func _build_visuals() -> void:
	_box(Vector3(1.95, 0.55, 4.2), Vector3(0, 0.0, 0), body_color)
	_box(Vector3(1.65, 0.55, 1.6), Vector3(0, 0.5, 0.25), Color("263b48"))
	_box(Vector3(1.8, 0.15, 0.15), Vector3(0, 0.0, -2.12), Color("e8dcab"))
	_box(Vector3(1.8, 0.15, 0.15), Vector3(0, 0.0, 2.12), Color("922d2e"))
	for mount in wheel_mounts:
		var pivot := Node3D.new()
		add_child(pivot)
		wheels.append(pivot)
		var mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = wheel_radius
		cylinder.bottom_radius = wheel_radius
		cylinder.height = 0.26
		mesh.mesh = cylinder
		mesh.rotation.z = PI / 2.0
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("171c22")
		mesh.material_override = material
		pivot.add_child(mesh)

func _box(size: Vector3, location: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = location
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	add_child(mesh)
