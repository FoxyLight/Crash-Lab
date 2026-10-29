extends CanvasLayer
@onready var vehicle = get_parent()
@onready var loadout = vehicle.get_node("Loadout")
var readout: Label

func _ready() -> void:
	readout = Label.new()
	readout.position = Vector2(20, 410)
	readout.add_theme_font_size_override("font_size", 18)
	readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	readout.add_theme_constant_override("shadow_offset_x", 2)
	readout.add_theme_constant_override("shadow_offset_y", 2)
	add_child(readout)

func _process(_delta: float) -> void:
	visible = vehicle.combat_active
	var weapon = loadout.weapons[loadout.selected_index]
	var status := "READY" if weapon.cooldown <= 0.0 else "COOLDOWN %.1fs" % weapon.cooldown
	if vehicle.get_node("DamageReceiver").is_destroyed:
		status = "DESTROYED"
	readout.text = "%s / %s\nQ / Controller Y — Switch   1 / 2 — Select\nHold LMB / F / RB — Fire forward" % [weapon.weapon_name, status]
