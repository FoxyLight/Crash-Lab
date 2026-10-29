extends MeshInstance3D
## Short-lived unlit flash, shared by muzzle and impact feedback.
var remaining: float = 0.12

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffe798")
	material_override = material

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	else:
		scale = Vector3.ONE * remaining / 0.12
