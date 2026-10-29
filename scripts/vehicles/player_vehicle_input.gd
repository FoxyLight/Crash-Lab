extends Node
## Replace this node with an AI/network provider exposing the same four fields.
var throttle: float = 0.0
var brake: float = 0.0
var steering: float = 0.0
var handbrake: bool = false
var reset_requested: bool = false

func _physics_process(_delta: float) -> void:
	throttle = Input.get_action_strength("accelerate")
	brake = Input.get_action_strength("brake_reverse")
	steering = Input.get_axis("steer_left", "steer_right")
	handbrake = Input.is_action_pressed("handbrake")
	reset_requested = reset_requested or Input.is_action_just_pressed("reset_vehicle")

