extends "res://scripts/vehicles/player_vehicle_input.gd"
@export var router: Node
@export_range(0, 1) var player_index: int = 0
var seen_revision: int = -1

func _ready() -> void:
	process_physics_priority = -20

func consume_weapon_selection() -> int:
	return router.consume_selection(player_index) if is_instance_valid(router) else -1

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(router):
		clear_commands()
		return
	if seen_revision != router.slot_revisions[player_index]:
		seen_revision = router.slot_revisions[player_index]
		reset_requested = false
	var reset: bool = router.consume(player_index, "reset")
	if not controls_enabled:
		clear_commands()
		return
	var state: Dictionary = router.commands(player_index)
	throttle = state.throttle
	brake = state.brake
	steering = state.steering
	handbrake = state.handbrake
	fire_requested = state.fire
	reset_requested = reset_requested or reset
