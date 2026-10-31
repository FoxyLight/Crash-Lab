extends CanvasLayer
@export var rival: RigidBody3D
@onready var health = rival.get_node("DamageReceiver")
@onready var driver = rival.get_node("DriverInput")
var readout: Label

func _ready() -> void:
	readout = Label.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	readout.offset_left = -420
	readout.offset_top = 20
	readout.offset_right = -20
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_size_override("font_size", 21)
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 2)
	readout.add_theme_constant_override("shadow_offset_y", 2)
	add_child(readout)
	var controls := Label.new()
	controls.position = Vector2(20, 20)
	controls.add_theme_font_size_override("font_size", 18)
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 2)
	controls.add_theme_constant_override("shadow_offset_y", 2)
	controls.text = "CRASH LAB / v0.11 DUEL\nW / S — Accelerate / Brake / Reverse\nA / D — Steer   SPACE — Handbrake   R — Reset\nHold LMB / F — Fire forward\nController: triggers / stick / A / D-pad up / RB"
	add_child(controls)

func _process(_delta: float) -> void:
	var status: String = driver.state
	if health.is_destroyed:
		status = "RESPAWN %.1fs" % maxf(health.respawn_remaining, 0.0) if not health.waiting_for_spawn else "WAITING FOR CLEAR SPAWN"
	elif health.protection_remaining > 0.0:
		status = "SPAWN SHIELD"
	readout.text = "BLUE RIVAL  /  %d : %d HP\n%s" % [health.health, health.maximum_health, status]
	rival.get_node("Nameplate").text = "RIVAL  /  %d HP\n%s" % [health.health, status]
