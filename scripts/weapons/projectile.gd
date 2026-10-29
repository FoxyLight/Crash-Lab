extends Node3D
signal impacted(location: Vector3)
## Sweeps the complete motion segment each physics tick; the visual has no collider.
const Flash = preload("res://scripts/weapons/hit_flash.gd")
var velocity: Vector3 = Vector3.ZERO
var damage: float = 20.0
var lifetime: float = 2.0
var shooter_rid: RID
var shooter_areas: Array[RID] = []
var age: float = 0.0
var color: Color = Color("7bffff")

func _ready() -> void:
	add_to_group("projectiles")
	var visual := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.12, 0.12, 0.65)
	visual.mesh = shape
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	visual.material_override = material
	add_child(visual)

func _physics_process(delta: float) -> void:
	var travel_time := minf(delta, maxf(lifetime - age, 0.0))
	var end := global_position + velocity * travel_time
	var excluded: Array[RID] = []
	if shooter_rid.is_valid():
		excluded.append(shooter_rid)
	excluded.append_array(shooter_areas)
	var query := PhysicsRayQueryParameters3D.create(global_position, end, 7, excluded)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage)
		else:
			var receiver = hit.collider.get_node_or_null("DamageReceiver")
			if receiver != null and receiver.has_method("take_damage"):
				receiver.take_damage(damage)
		var flash := Flash.new()
		get_tree().current_scene.add_child(flash)
		flash.global_position = hit.position
		impacted.emit(hit.position)
		queue_free()
		return
	global_position = end
	age += delta
	if age >= lifetime:
		queue_free()
