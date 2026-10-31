extends Node3D
## Metres throughout. Runway occupies x < 0; the handling course is on the right.
func _ready() -> void:
	_block("Ground", Vector3(130, 1, 180), Vector3(0, -0.5, -35), Color("343e47"))
	_block("WestBarrier", Vector3(1, 2, 180), Vector3(-65, 1, -35), Color("778591"))
	_block("EastBarrier", Vector3(1, 2, 180), Vector3(65, 1, -35), Color("778591"))
	_block("NorthBarrier", Vector3(130, 2, 1), Vector3(0, 1, -125), Color("778591"))
	_block("SouthBarrier", Vector3(130, 2, 1), Vector3(0, 1, 55), Color("778591"))
	for i in range(12):
		_block("RunwayMark", Vector3(0.25, 0.015, 5), Vector3(-25, 0.015, 35 - i * 13), Color("d4d1b4"), false)
	for i in range(7):
		_block("Slalom", Vector3(2, 1.7, 2), Vector3(19 + (5 if i % 2 == 0 else -5), 0.85, 15 - i * 13), Color("e6aa49"))
	_block("ImpactBlock", Vector3(5, 3, 5), Vector3(42, 1.5, -45), Color("7e94a0"))
	_block("ImpactBlock", Vector3(4, 2, 7), Vector3(-45, 1, -75), Color("7e94a0"))
	# A long shallow ramp, aligned with forward travel (-Z).
	_block("Ramp", Vector3(9, 0.5, 14), Vector3(0, 1.2, -55), Color("5f8390"), true, Vector3(0.16, 0, 0))
	_block("LandingRamp", Vector3(9, 0.5, 14), Vector3(0, 1.2, -68.82), Color("5f8390"), true, Vector3(-0.16, 0, 0))
	_label("OPEN RUNWAY", Vector3(-25, 0.04, 35))
	_label("HANDLING", Vector3(20, 0.04, 35))
	_label("RAMPS", Vector3(0, 0.04, -36))
	_label("REPAIR PRACTICE", Vector3(-48, 0.04, 36))
	_label("FIRING RANGE", Vector3(48, 0.04, 32))
	_block("RangeBackstop", Vector3(14, 6, 1), Vector3(48, 3, -20), Color("617c85"))
	for i in range(5):
		_block("RangeMark", Vector3(0.2, 0.015, 3), Vector3(48, 0.02, 24 - i * 7), Color("7bcccc"), false)
	var target = preload("res://scenes/targets/target_dummy.tscn").instantiate()
	target.name = "TargetDummy"
	target.position = Vector3(48, 0, -12)
	add_child(target)
	_label("COMBAT ZONE", Vector3(40, 0.04, -75))
	_block("CombatCover", Vector3(4, 3, 2), Vector3(30, 1.5, -95), Color("617c85"))
	_block("CombatCover", Vector3(4, 3, 2), Vector3(51, 1.5, -82), Color("617c85"))
	_destruction_practice()

func _destruction_practice() -> void:
	var manager := _destruction_manager()
	_prop(manager, "breakable_crate", Vector3(-51, 0.9, -4))
	_prop(manager, "breakable_crate", Vector3(-57, 0.9, -4))
	_prop(manager, "destructible_barrier", Vector3(-52, 1.2, -23))
	_prop(manager, "energy_canister", Vector3(-52, 1.1, -44))
	_label("DESTRUCTION / RAM OR SHOOT", Vector3(-50, 0.04, 5))

func _destruction_manager() -> Node3D:
	var manager := Node3D.new()
	manager.set_script(preload("res://scripts/destruction/destruction_manager.gd"))
	manager.name = "Destruction"
	add_child(manager)
	return manager

func _prop(manager: Node3D, type: String, location: Vector3) -> Node3D:
	var prop = load("res://scenes/props/%s.tscn" % type).instantiate()
	prop.position = location
	manager.add_child(prop)
	return prop

func _block(title: String, size: Vector3, location: Vector3, color: Color, solid: bool = true, tilt: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	body.position = location
	body.rotation = tilt
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)

func _label(text: String, location: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 100
	label.pixel_size = 0.02
	label.position = location
	label.rotation_degrees.x = -90
	add_child(label)
