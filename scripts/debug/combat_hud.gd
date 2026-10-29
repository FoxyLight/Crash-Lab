extends CanvasLayer
@export var vehicle: RigidBody3D
@export var enemy: Node3D
@onready var health = vehicle.get_node("DamageReceiver")
var bar: ProgressBar
var status: Label
var hit_overlay: ColorRect
var flash: float = 0.0
var hint: Label
var fill: StyleBoxFlat

func _ready() -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 20
	panel.offset_top = -115
	panel.offset_right = 430
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 21)
	panel.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(410, 25)
	bar.show_percentage = false
	fill = StyleBoxFlat.new()
	fill.bg_color = Color("48cd9b")
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)
	hint = Label.new()
	hint.text = "COMBAT ZONE: northeast corner / orange turret"
	panel.add_child(hint)
	hit_overlay = ColorRect.new()
	hit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_overlay.color = Color(1, 0.1, 0.05, 0)
	add_child(hit_overlay)
	health.damaged.connect(func(): flash = 0.18)

func _process(delta: float) -> void:
	bar.max_value = health.maximum_health
	bar.value = health.health
	fill.bg_color = Color("f26353") if health.health < health.maximum_health * 0.3 else Color("48cd9b")
	hint.text = "COMBAT ZONE: northeast corner / orange turret"
	hint.modulate = Color.WHITE
	if is_instance_valid(enemy):
		if enemy.is_destroyed:
			hint.text = "TURRET DESTROYED — Returns in %.1fs" % maxf(enemy.respawn_remaining, 0.0)
		elif enemy.lock_time > 0.0:
			hint.text = "TURRET FIRING — DODGE!" if enemy.fire_requested else "TURRET LOCKING — Keep moving!"
			hint.modulate = Color("ffb66e")
	if health.is_destroyed:
		status.text = "DESTROYED — Respawn in %.1fs" % maxf(health.respawn_remaining, 0.0)
	elif health.protection_remaining > 0.0:
		status.text = "HEALTH %d / %d  |  SPAWN SHIELD" % [health.health, health.maximum_health]
	else:
		status.text = "HEALTH %d / %d" % [health.health, health.maximum_health]
	flash = maxf(0.0, flash - delta)
	hit_overlay.color.a = flash
