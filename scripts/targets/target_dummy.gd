extends StaticBody3D
## Reusable damage receiver. Only explicit damage calls change health.
signal health_changed(health: float, maximum: float)
signal destroyed
signal respawned
@export_range(1.0, 10000.0, 1.0) var maximum_health: float = 100.0
@export_range(0.1, 30.0, 0.1) var respawn_delay: float = 3.0
var health: float = 100.0
var is_destroyed: bool = false
var respawn_remaining: float = 0.0
var flash_remaining: float = 0.0
@onready var visual: MeshInstance3D = $Body
@onready var label: Label3D = $HealthLabel
@onready var collider: CollisionShape3D = $CollisionShape3D
var material: StandardMaterial3D

func _ready() -> void:
	material = StandardMaterial3D.new()
	visual.material_override = material
	_restore()

func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	flash_remaining = 0.12
	health_changed.emit(health, maximum_health)
	if health <= 0.0:
		is_destroyed = true
		respawn_remaining = respawn_delay
		collider.set_deferred("disabled", true)
		destroyed.emit()
	_update_display()

func _physics_process(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if is_destroyed:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			_restore()
	_update_display()

func _restore() -> void:
	health = maximum_health
	is_destroyed = false
	flash_remaining = 0.0
	visual.scale = Vector3.ONE
	collider.set_deferred("disabled", false)
	health_changed.emit(health, maximum_health)
	respawned.emit()
	_update_display()

func _update_display() -> void:
	if is_destroyed:
		visual.scale = Vector3(1, 0.15, 1)
		material.albedo_color = Color("41464e")
		label.text = "DESTROYED\nRespawn in %.1fs" % maxf(respawn_remaining, 0.0)
	else:
		material.albedo_color = Color.WHITE if flash_remaining > 0.0 else Color("df6444")
		label.text = "TARGET  /  %d : %d HP" % [health, maximum_health]
