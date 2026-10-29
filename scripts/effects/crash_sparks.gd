extends Node3D
## One mesh per burst, eight at most per scene. No simulated debris bodies.
var severity: int = 1
var normal := Vector3.UP
var remaining: float = 0.0
var duration: float = 0.0
var material: StandardMaterial3D

func _ready() -> void:
	add_to_group("combat_effects")
	add_to_group("crash_effects")
	duration = 0.18 + severity * 0.08
	remaining = duration
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("ffe4a3") if severity < 3 else Color("ffad50")
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var count := 4 + severity * 4
	for i in count:
		var angle := TAU * float(i) / count
		var direction := (Vector3(cos(angle), 0.6 + float(i % 3) * 0.35, sin(angle)) + normal * 0.7).normalized()
		mesh.surface_add_vertex(direction * 0.05)
		mesh.surface_add_vertex(direction * (0.25 + severity * 0.20))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var progress := 1.0 - remaining / duration
	scale = Vector3.ONE * (1.0 + progress * 1.8)
	material.albedo_color.a = 1.0 - progress
