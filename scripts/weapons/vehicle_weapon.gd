extends Node3D
## Consumes commands without applying any force or changing chassis properties.
signal shot_fired
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

func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if is_instance_valid(input_provider) and input_provider.fire_requested and cooldown <= 0.0:
		_fire()
		cooldown = 1.0 / maxf(fire_rate, 0.1)

func _fire() -> void:
	var projectile := Projectile.new()
	projectile.velocity = -muzzle.global_basis.z * projectile_speed
	projectile.damage = projectile_damage
	projectile.lifetime = projectile_lifetime
	projectile.color = projectile_color
	projectile.shooter_rid = shooter.get_rid() if is_instance_valid(shooter) else RID()
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = muzzle.global_transform
	var flash := Flash.new()
	muzzle.add_child(flash)
	shot_fired.emit()
