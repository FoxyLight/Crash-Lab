extends Area3D
## Non-solid physical-body overlap. Selection is atomic and independent of AI.
signal collected(actor: RigidBody3D, amount: float)
@export_range(1.0, 100.0) var repair_amount: float = 25.0
@export_range(0.1, 60.0) var respawn_delay: float = 12.0
@export_range(0.5, 5.0) var collection_radius: float = 2.0
var available: bool = true
var enabled: bool = true
var remaining: float = 0.0
@onready var label: Label3D = $Label
@onready var marker: Node3D = $Marker
var base_material: StandardMaterial3D

func _ready() -> void:
	process_physics_priority = 10
	add_to_group("repair_pickups")
	var shape := CylinderShape3D.new()
	shape.radius = collection_radius
	shape.height = 2.5
	$CollectionShape.shape = shape
	base_material = StandardMaterial3D.new()
	$Base.material_override = base_material
	var ancestor := get_parent()
	while ancestor != null:
		var match_node := ancestor.get_node_or_null("MatchController")
		if match_node != null:
			match_node.match_finished.connect(finish_collection)
			if match_node.state == 1:
				finish_collection(0)
			break
		ancestor = ancestor.get_parent()
	_update_display()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if not available:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			available = true
	try_collect()
	_update_display()

func try_collect() -> bool:
	if not enabled or not available:
		return false
	var candidates: Array[RigidBody3D] = []
	# Query actual physics shapes each available tick, including stationary/frozen
	# bodies, rather than relying on cached area entry/exit notifications.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = $CollectionShape.shape
	query.transform = $CollectionShape.global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body = hit.collider
		if not body is RigidBody3D or (body.collision_layer & 2) == 0:
			continue
		var health = body.get_node_or_null("DamageReceiver")
		if health != null and health.has_method("restore_health") and health.combat_active and not health.is_destroyed and health.health < health.maximum_health:
			if not candidates.has(body):
				candidates.append(body)
	if candidates.is_empty():
		return false
	candidates.sort_custom(_nearer_first)
	# Mark unavailable before calling receiver signals: reentrant attempts cannot win twice.
	available = false
	var actor := candidates[0]
	var restored: float = actor.get_node("DamageReceiver").restore_health(repair_amount)
	if not enabled:
		return false
	if restored <= 0.0:
		available = true
		return false
	remaining = respawn_delay
	collected.emit(actor, restored)
	_update_display()
	return true

func _nearer_first(a: RigidBody3D, b: RigidBody3D) -> bool:
	var da := global_position.distance_squared_to(a.global_position)
	var db := global_position.distance_squared_to(b.global_position)
	# Exact-distance ties use stable lexical scene paths (Player before Rival).
	return str(a.get_path()) < str(b.get_path()) if da == db else da < db

func finish_collection(_result: int) -> void:
	enabled = false
	remaining = 0.0
	set_physics_process(false)
	_update_display()

func _update_display() -> void:
	marker.visible = available and enabled
	base_material.albedo_color = Color("287b55") if available and enabled else Color("414c52")
	if not enabled:
		label.text = "REPAIR / INACTIVE"
	elif available:
		var amount_text := str(int(repair_amount)) if repair_amount == floorf(repair_amount) else str(repair_amount)
		label.text = "REPAIR +%s HP" % amount_text
	else:
		label.text = "REPAIR\nReturns in %.1fs" % remaining
