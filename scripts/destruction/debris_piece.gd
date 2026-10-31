extends MeshInstance3D
## Non-solid ballistic fragments: no body, area, suspension or projectile hits.
var velocity := Vector3.ZERO
var spin := Vector3.ZERO
var age: float = 0.0
var lifetime: float = 2.5
var floor_y: float = 0.1

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	velocity.y -= 12.0 * delta
	position += velocity * delta
	rotation += spin * delta
	if global_position.y < floor_y:
		global_position.y = floor_y
		velocity.y = absf(velocity.y) * 0.2
		velocity.x *= 0.8
		velocity.z *= 0.8
	scale = Vector3.ONE * clampf((lifetime - age) / 0.4, 0.0, 1.0)
