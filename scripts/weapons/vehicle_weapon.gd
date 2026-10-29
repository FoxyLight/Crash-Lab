extends Node3D
## Consumes commands without applying any force or changing chassis properties.
signal shot_fired
signal projectile_impacted(location: Vector3)
const Projectile = preload("res://scripts/weapons/projectile.gd")
const Flash = preload("res://scripts/weapons/hit_flash.gd")
@export var input_provider: Node
@export var shooter: CollisionObject3D
@export var projectile_color: Color = Color("7bffff")
@export_range(0.1, 120.0, 0.1) var fire_rate: float = 7.0
@export_range(1.0, 20000.0, 1.0) var projectile_speed: float = 110.0
@export_range(0.0, 1000.0, 1.0) var projectile_damage: float = 20.0
@export_range(0.05, 10.0, 0.05) var projectile_lifetime: float = 2.0
@onready var muzzle: Marker3D = $Muzzle
var cooldown: float = 0.0
var firing_enabled: bool = true

func stop_firing() -> void:
	firing_enabled = false
	cooldown = 0.0
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not firing_enabled:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	if is_instance_valid(input_provider) and input_provider.fire_requested and cooldown <= 0.0:
		_fire()
		cooldown = 1.0 / maxf(fire_rate, 0.1)

func _fire() -> void:
	if not firing_enabled:
		return
	var projectile := Projectile.new()
	projectile.impacted.connect(_on_projectile_impact)
	projectile.velocity = -muzzle.global_basis.z * projectile_speed
	projectile.damage = projectile_damage
	projectile.lifetime = projectile_lifetime
	projectile.color = projectile_color
	projectile.shooter_rid = shooter.get_rid() if is_instance_valid(shooter) else RID()
	if is_instance_valid(shooter):
		for area in shooter.find_children("*", "Area3D", true, false):
			projectile.shooter_areas.append(area.get_rid())
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = muzzle.global_transform
	var flash := Flash.new()
	muzzle.add_child(flash)
	shot_fired.emit()

func _on_projectile_impact(location: Vector3) -> void:
	projectile_impacted.emit(location)
