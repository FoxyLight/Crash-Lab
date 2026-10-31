extends RigidBody3D
## Lightweight crates yield physically; frozen barriers remain genuine cover.
signal durability_changed(current: float, maximum: float)
signal destroyed(prop: Node3D, source: Node)
signal sound_requested(cue: StringName, location: Vector3)
@export_enum("Crate", "Barrier", "Hazard") var kind: int = 0
@export var maximum_durability: float = 40.0
@export var dimensions := Vector3(2, 1.8, 2)
@export var body_color := Color("bd803c")
@export var minimum_ram_speed: float = 6.0
@export var ram_damage_per_mps: float = 6.0
@export_range(0, 8) var debris_count: int = 8
@export var destruction_audio: bool = true
@export var fuse_duration: float = 0.8
@export var blast_radius: float = 12.0
@export var blast_damage: float = 45.0
var durability: float
var is_destroyed: bool = false
var primed: bool = false
var fuse_remaining: float = 0.0
var detonation_count: int = 0
var last_source: WeakRef
var ram_episodes: Dictionary = {}
var manager: Node
var visuals: Node3D
var collider: CollisionShape3D
var material: StandardMaterial3D
var label: Label3D
var warning: MeshInstance3D

func _ready() -> void:
	add_to_group("destructible_props")
	manager = get_parent()
	durability = maximum_durability
	collision_layer = 1
	collision_mask = 3
	mass = 18.0
	continuous_cd = true
	linear_damp = 0.8
	angular_damp = 2.0
	freeze = kind != 0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	collider = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collider.shape = box
	add_child(collider)
	visuals = Node3D.new()
	add_child(visuals)
	material = StandardMaterial3D.new()
	material.albedo_color = body_color
	_mesh(dimensions, Vector3.ZERO, material)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("3a3430") if kind == 0 else Color("ffce54")
	for side in [-1.0, 1.0]:
		_mesh(Vector3(dimensions.x + 0.04, 0.16, dimensions.z + 0.04), Vector3(0, side * dimensions.y * 0.32, 0), trim)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = dimensions.y * 0.5 + 0.7
	label.font_size = 34
	label.pixel_size = 0.012
	add_child(label)
	_update_label()

func _mesh(size: Vector3, offset: Vector3, surface: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = surface
	mesh.position = offset
	visuals.add_child(mesh)

func _update_label() -> void:
	var title: String = ["CRATE", "BREAKABLE COVER", "DANGER / ENERGY"][kind]
	label.text = "%s  %d/%d" % [title, durability, maximum_durability]

func take_damage(amount: float) -> void:
	take_damage_from(amount, null)

func take_damage_from(amount: float, source: Node) -> void:
	if is_destroyed or not manager.active() or not is_finite(amount) or amount <= 0.0:
		return
	durability = maxf(0.0, durability - amount)
	last_source = weakref(source) if is_instance_valid(source) else null
	material.albedo_color = body_color.lerp(Color("3a2720"), 0.65 * (1.0 - durability / maximum_durability))
	_update_label()
	durability_changed.emit(durability, maximum_durability)
	if durability <= 0.0 and not is_destroyed:
		_break(source)

func receive_vehicle_impact(data: Dictionary) -> void:
	# ImpactDetector supplies the strongest physical normal closing speed, not
	# chassis speed. Its episode key survives upgrades and changes on separation.
	var speed: float = data.closing_speed
	if is_destroyed or not is_finite(speed) or speed < minimum_ram_speed:
		return
	var id: int = data.vehicle.get_instance_id()
	var episode: float = data.episode_started
	var entry: Dictionary = ram_episodes.get(id, {"episode": -INF, "damage": 0.0})
	if entry.episode != episode:
		entry = {"episode": episode, "damage": 0.0}
	var total := maxf(0.0, speed - 4.0) * ram_damage_per_mps
	var additional := maxf(0.0, total - entry.damage)
	entry.damage = maxf(entry.damage, total)
	ram_episodes[id] = entry
	# Ramming the hazard is environmental, never implicit opponent credit.
	take_damage_from(additional, null if kind == 2 else data.vehicle)

func _break(source: Node) -> void:
	is_destroyed = true # Set before notifying any observers: one transition.
	collision_layer = 0
	collision_mask = 0
	collider.set_deferred("disabled", true)
	set_deferred("freeze", true)
	destroyed.emit(self, source)
	if kind == 2:
		primed = true
		fuse_remaining = maxf(0.1, fuse_duration)
		warning = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = maxf(0.1, blast_radius - 0.12)
		ring.outer_radius = blast_radius
		warning.mesh = ring
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("ff7a24")
		warning.material_override = glow
		add_child(warning)
		warning.position.y = -dimensions.y * 0.5 + 0.08
	else:
		visuals.hide()
		label.text = "BROKEN / ROUTE OPEN"
		manager.breakup(global_position, dimensions, body_color, debris_count)
		if destruction_audio:
			sound_requested.emit(&"wood_break" if kind == 0 else &"barrier_break", global_position)

func _physics_process(delta: float) -> void:
	if not primed:
		return
	if not manager.active():
		cancel_pending()
		return
	fuse_remaining -= delta
	label.text = "BLAST IN %.1f s / MOVE!" % maxf(0, fuse_remaining)
	material.albedo_color = Color("ffce54") if fmod(fuse_remaining, 0.2) < 0.1 else Color("b8281d")
	if fuse_remaining <= 0.0:
		_detonate()

func _detonate() -> void:
	if not primed or not manager.active():
		return
	primed = false
	detonation_count += 1
	visuals.hide()
	warning.queue_free()
	label.text = "SPENT / SAFE"
	# Only registered vehicle health receivers; props never chain-react.
	var source: Node = last_source.get_ref() if last_source != null else null
	for actor in manager.vehicles():
		var health = actor.get_node("DamageReceiver")
		var distance: float = actor.global_position.distance_to(global_position)
		if distance >= blast_radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, actor.global_position, 1, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue # Intact world cover shields the blast.
		var amount := blast_damage * (1.0 - distance / blast_radius)
		health.take_damage_from(amount, source)
	manager.breakup(global_position, Vector3(5, 4, 5), Color("ff982e"), debris_count)
	manager.blast_visual(global_position, blast_radius)
	if destruction_audio:
		sound_requested.emit(&"hazard_blast", global_position)

func cancel_pending() -> void:
	primed = false
	if is_instance_valid(warning):
		warning.queue_free()
	if is_destroyed:
		visuals.hide()
		label.hide()
