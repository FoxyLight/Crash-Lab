extends Node3D
## One scene-owned effects budget, shared by both cameras.
const Piece = preload("res://scripts/destruction/debris_piece.gd")
@export_range(0, 64) var maximum_debris: int = 64
@export_range(0.2, 3.0) var debris_lifetime: float = 2.5
var pieces: Array[MeshInstance3D] = []
var match_node: Node
var enabled: bool = true
var burst_index: int = 0
var blast_effects: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("destruction_managers")
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_node("MatchController"):
			match_node = ancestor.get_node("MatchController")
			match_node.match_finished.connect(finish)
			break
		ancestor = ancestor.get_parent()

func active() -> bool:
	return enabled and (not is_instance_valid(match_node) or match_node.state == 0)

func vehicles() -> Array[Node]:
	var actors: Array[Node] = []
	for detector in get_tree().get_nodes_in_group("vehicle_impacts"):
		if get_parent().get_parent().is_ancestor_of(detector):
			actors.append(detector.get_parent())
	return actors

func breakup(location: Vector3, size: Vector3, color: Color, count: int) -> void:
	if not active():
		return
	_prune()
	burst_index += 1
	for i in mini(8, clampi(count, 0, maximum_debris - pieces.size())):
		var piece := Piece.new()
		var box := BoxMesh.new()
		box.size = Vector3(size.x * 0.28, size.y * 0.24, size.z * 0.28)
		piece.mesh = box
		var surface := StandardMaterial3D.new()
		surface.albedo_color = color.lightened(0.15 if i % 2 == 0 else 0.0)
		piece.material_override = surface
		piece.lifetime = debris_lifetime
		# Deterministic fan, no shared gameplay RNG.
		var angle := i * TAU / 8.0 + burst_index * 0.7
		var direction := Vector3(cos(angle), 0, sin(angle))
		piece.velocity = direction * (3.0 + i * 0.4) + Vector3.UP * (3.0 + i * 0.25)
		piece.spin = Vector3(i + 1, 2.0, -i - 1)
		add_child(piece)
		piece.global_position = location + direction * 0.4
		pieces.append(piece)

func _prune() -> void:
	for i in range(pieces.size() - 1, -1, -1):
		if not is_instance_valid(pieces[i]) or pieces[i].is_queued_for_deletion():
			pieces.remove_at(i)

func _physics_process(_delta: float) -> void:
	_prune()

func blast_visual(location: Vector3, radius: float) -> void:
	if not active():
		return
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.2
	sphere.height = radius * 0.4
	mesh.mesh = sphere
	var surface := StandardMaterial3D.new()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.albedo_color = Color("ffad37")
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = surface
	add_child(mesh)
	mesh.global_position = location
	blast_effects.append(mesh)
	var tween := mesh.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3.ONE * 3.0, 0.3)
	tween.tween_property(surface, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(mesh.queue_free)

func finish(_result: int = 0) -> void:
	enabled = false
	for prop in get_children():
		if prop.has_method("cancel_pending"):
			prop.cancel_pending()
	for piece in pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	pieces.clear()
	for effect in blast_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	blast_effects.clear()
