extends Control
## Compact per-viewport presentation. Gameplay actors remain in the shared world.
var vehicle: RigidBody3D
var match_controller: Node
var router: Node
var player_index: int = 0
var identity: Label
var score: Label
var status: Label
var weapon_status: Label
var device_status: Label
var repair_message: Label
var bar: ProgressBar
var overlay: ColorRect
var flash: float = 0.0
var repair_remaining: float = 0.0

func _label(position_at: Vector2, font: int = 18) -> Label:
	var label := Label.new()
	label.position = position_at
	label.add_theme_font_size_override("font_size", font)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity = _label(Vector2(16, 8), 21)
	identity.modulate = Color("ffbd8a") if player_index == 0 else Color("8fdcff")
	device_status = _label(Vector2(16, 36), 15)
	score = _label(Vector2.ZERO, 18)
	score.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	score.offset_left = -360
	score.offset_right = -16
	score.offset_top = 10
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status = _label(Vector2.ZERO)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 16
	status.offset_top = -62
	bar = ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 16
	bar.offset_top = -32
	bar.offset_right = 246
	bar.offset_bottom = -12
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("48cd9b")
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	weapon_status = _label(Vector2.ZERO)
	weapon_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_status.offset_left = -335
	weapon_status.offset_right = -16
	weapon_status.offset_top = -65
	weapon_status.offset_bottom = -10
	weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	repair_message = _label(Vector2(16, 64))
	repair_message.modulate = Color("75ffac")
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(1, 0.1, 0.05, 0)
	add_child(overlay)
	var health = vehicle.get_node("DamageReceiver")
	health.damaged.connect(func(): flash = 0.18)
	health.respawned.connect(_clear_feedback)
	for pad in get_tree().get_nodes_in_group("repair_pickups"):
		pad.collected.connect(_on_repair)

func _on_repair(actor: RigidBody3D, amount: float) -> void:
	if actor == vehicle and vehicle.combat_active:
		repair_message.text = "REPAIRED +%s HP" % str(snappedf(amount, 0.1))
		repair_remaining = 1.5

func _clear_feedback() -> void:
	flash = 0.0
	repair_remaining = 0.0

func _process(delta: float) -> void:
	visible = vehicle.combat_active
	var health = vehicle.get_node("DamageReceiver")
	var loadout = vehicle.get_node("Loadout")
	var weapon = loadout.weapons[loadout.selected_index]
	identity.text = "PLAYER %d  •  %03d km/h" % [player_index + 1, vehicle.linear_velocity.length() * 3.6]
	var driving := "WASD: Drive   Space: Handbrake" if player_index == 0 and not router.two_gamepads else "Triggers / stick: Drive   A: Handbrake"
	device_status.text = "%s  |  %s" % [router.device_label(player_index), driving]
	score.text = "P1 %d — %d P2  |  First to %d" % [match_controller.player_score, match_controller.rival_score, match_controller.elimination_target]
	bar.max_value = health.maximum_health
	bar.value = health.health
	status.text = "HEALTH %d / %d%s" % [health.health, health.maximum_health, "  SHIELD" if health.protection_remaining > 0.0 else ""]
	if health.is_destroyed:
		status.text = "Finding safe spawn…" if health.waiting_for_spawn else "RESPAWN %.1fs" % health.respawn_remaining
	var ready_text := "READY" if weapon.cooldown <= 0.0 else "%.1fs" % weapon.cooldown
	var controls := "F / LMB: Fire   Q: Switch   R: Reset" if player_index == 0 and not router.two_gamepads else "RB: Fire   Y: Switch   D-pad up: Reset"
	weapon_status.text = "%s  •  %s\n%s" % [weapon.weapon_name, "DESTROYED" if health.is_destroyed else ready_text, controls]
	flash = maxf(0.0, flash - delta)
	overlay.color.a = flash
	repair_remaining = maxf(0.0, repair_remaining - delta)
	repair_message.visible = repair_remaining > 0.0 and vehicle.combat_active
	var nameplate: Label3D = vehicle.get_node("Nameplate")
	nameplate.text = "P%d  /  %d HP%s" % [player_index + 1, health.health, "  SHIELD" if health.protection_remaining > 0.0 else ""]
	if health.is_destroyed:
		nameplate.text = "P%d  /  DESTROYED" % (player_index + 1)
