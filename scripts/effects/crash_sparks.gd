extends Node3D
## Thick camera-facing streaks and a white-hot center. Compatibility renderer;
## no glow, particles, physics bodies or shared gameplay RNG required.
var severity: int = 1
var normal := Vector3.UP
var remaining: float = 0.0
var duration: float = 0.0
var material: StandardMaterial3D
var streak_mesh: ImmediateMesh
var center: MeshInstance3D
var center_material: StandardMaterial3D
var velocities: Array[Vector3] = []
var streak_count: int = 0

func _ready() -> void:
	add_to_group("combat_effects")
	add_to_group("crash_effects")
	severity = clampi(severity, 1, 3)
	duration = [0.0, 0.30, 0.45, 0.65][severity]
	remaining = duration
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak_mesh = ImmediateMesh.new()
	streak_count = [0, 8, 12, 18][severity]
	for i in streak_count:
		var angle := TAU * float(i) / streak_count
		var direction := (Vector3(cos(angle), 0.7 + float(i % 3) * 0.35, sin(angle)) + normal * 0.6).normalized()
		velocities.append(direction * (2.0 + severity * 0.8 + (i % 4) * 0.4))
	var visual := MeshInstance3D.new()
	visual.mesh = streak_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	center = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.10 + severity * 0.055
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	center.mesh = sphere
	center_material = StandardMaterial3D.new()
	center_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	center_material.albedo_color = Color("fff9d2")
	center.material_override = center_material
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(center)
	_draw_streaks()

func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var age := duration - remaining
	center_material.albedo_color.a = maxf(0.0, 1.0 - age / 0.22)
	center.scale = Vector3.ONE * (1.0 + age * 3.0)
	_draw_streaks()

func _draw_streaks() -> void:
	var age := duration - remaining
	# Hold contrast through the travel phase, then fade over the final 0.24 s.
	var opacity := clampf(remaining / minf(duration, 0.24), 0.0, 1.0)
	var camera := get_viewport().get_camera_3d()
	var view := (camera.global_position - global_position).normalized() if camera != null else Vector3.BACK
	streak_mesh.clear_surfaces()
	streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for velocity in velocities:
		var head := velocity * (age + 0.03) + Vector3.DOWN * age * age * 2.0
		var tail := head - velocity.normalized() * (0.30 + severity * 0.27) * maxf(0.5, opacity)
		var side := velocity.normalized().cross(view).normalized()
		if side.length_squared() < 0.1:
			side = Vector3.RIGHT
		side *= (0.025 + severity * 0.016) * maxf(0.7, opacity)
		var points := [tail - side, head - side, head + side, tail - side, head + side, tail + side]
		for i in points.size():
			var color := Color("fff5ab") if i in [1, 2, 4] else Color("ff8e25")
			color.a = opacity
			streak_mesh.surface_set_color(color)
			streak_mesh.surface_add_vertex(points[i])
	streak_mesh.surface_end()
