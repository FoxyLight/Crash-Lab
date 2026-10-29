extends Node
## Health stays separate from chassis physics. Recovery uses the existing reset command.
signal health_changed(health: float, maximum: float)
signal damaged
signal destroyed
signal respawned
@export_range(1.0, 1000.0) var maximum_health: float = 100.0
@export_range(0.1, 10.0) var respawn_delay: float = 3.0
@export_range(0.0, 5.0) var spawn_protection: float = 1.5
@export_range(0.0, 10.0) var alternate_spawn_delay: float = 1.5
var health: float
var is_destroyed: bool = false
var respawn_remaining: float = 0.0
var protection_remaining: float = 0.0
var hit_remaining: float = 0.0
var waiting_for_spawn: bool = false
var pending_reset_generation: int = -1
var combat_active: bool = true
var spawn_blocked_time: float = 0.0
var death_source: WeakRef
@onready var vehicle: RigidBody3D = get_parent()
@onready var driver = vehicle.get_node("DriverInput")
var meshes: Array[MeshInstance3D] = []
var tint: StandardMaterial3D

func finish_combat() -> void:
	combat_active = false
	respawn_remaining = 0.0
	pending_reset_generation = -1
	waiting_for_spawn = false
	set_physics_process(false)

func _ready() -> void:
	process_physics_priority = -10
	health = maximum_health
	tint = StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Chassis placeholder meshes are created by the parent's _ready().
	_collect_meshes.call_deferred()

func _collect_meshes() -> void:
	for node in vehicle.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)

func take_damage(amount: float) -> void:
	take_damage_from(amount, null)

func take_damage_from(amount: float, source: Node) -> void:
	if not combat_active or is_destroyed or protection_remaining > 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	hit_remaining = 0.15
	health_changed.emit(health, maximum_health)
	damaged.emit()
	if health <= 0.0:
		# Only this accepted lethal hit decides credit. Never reuse an old attacker
		# after an unattributed/environmental final hit, repair, or another life.
		death_source = weakref(source) if is_instance_valid(source) else null
		is_destroyed = true
		respawn_remaining = respawn_delay
		pending_reset_generation = -1
		driver.controls_enabled = false
		driver.clear_commands()
		driver.reset_requested = false
		destroyed.emit()

func get_death_source() -> Node:
	return death_source.get_ref() if death_source != null else null

func restore_health(amount: float) -> float:
	if not combat_active or is_destroyed or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var before := health
	health = minf(maximum_health, health + amount)
	var restored := maxf(0.0, health - before)
	if restored > 0.0:
		health_changed.emit(health, maximum_health)
	return restored

func _physics_process(delta: float) -> void:
	if not combat_active:
		return
	hit_remaining = maxf(0.0, hit_remaining - delta)
	protection_remaining = maxf(0.0, protection_remaining - delta)
	if is_destroyed:
		respawn_remaining = maxf(0.0, respawn_remaining - delta)
		if respawn_remaining <= 0.0:
			waiting_for_spawn = true
			spawn_blocked_time += delta
			if (pending_reset_generation < 0 or vehicle.reset_generation < pending_reset_generation) and vehicle.prepare_respawn(spawn_blocked_time >= alternate_spawn_delay):
				if pending_reset_generation < 0:
					pending_reset_generation = vehicle.reset_generation + 1
				driver.reset_requested = true
			if pending_reset_generation >= 0 and vehicle.reset_generation >= pending_reset_generation:
				is_destroyed = false
				waiting_for_spawn = false
				health = maximum_health
				protection_remaining = spawn_protection
				spawn_blocked_time = 0.0
				death_source = null
				driver.controls_enabled = true
				health_changed.emit(health, maximum_health)
				respawned.emit()
	else:
		driver.controls_enabled = true
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		mesh.material_overlay = tint if is_destroyed or hit_remaining > 0.0 else null
	if is_destroyed:
		tint.albedo_color = Color("242831")
	else:
		tint.albedo_color = Color("ffb1a0")
