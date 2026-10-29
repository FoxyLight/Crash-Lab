extends Node
## Replace this node with an AI/network provider exposing the same command fields.
var fire_requested: bool = false
var controls_enabled: bool = true
var throttle: float = 0.0
var brake: float = 0.0
var steering: float = 0.0
var handbrake: bool = false
var reset_requested: bool = false
var weapon_cycle_armed: bool = true

func consume_weapon_selection() -> int:
	var cycle_pressed := Input.is_action_pressed("cycle_weapon")
	if not cycle_pressed:
		weapon_cycle_armed = true
	var cycle := Input.is_action_just_pressed("cycle_weapon") and weapon_cycle_armed
	if cycle_pressed:
		weapon_cycle_armed = false
	# Direct slot 1 wins over slot 2; either wins over cycle in the same tick.
	if Input.is_action_just_pressed("select_blaster"):
		return 0
	if Input.is_action_just_pressed("select_cannon"):
		return 1
	return -2 if cycle else -1

func stop_commands() -> void:
	controls_enabled = false
	clear_commands()
	reset_requested = false
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		clear_commands()
		return
	fire_requested = Input.is_action_pressed("fire_weapon")
	throttle = Input.get_action_strength("accelerate")
	brake = Input.get_action_strength("brake_reverse")
	steering = Input.get_axis("steer_left", "steer_right")
	handbrake = Input.is_action_pressed("handbrake")
	reset_requested = reset_requested or Input.is_action_just_pressed("reset_vehicle")

func clear_commands() -> void:
	throttle = 0.0
	brake = 0.0
	steering = 0.0
	handbrake = false
	fire_requested = false

