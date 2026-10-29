extends SceneTree
## One minute of unattended default-arena combat, with bounded physics steps.
var deaths: int = 0
var shots: int = 0

func _initialize() -> void:
	create_timer(90.0, true, true).timeout.connect(func(): push_error("Soak exceeded 90 simulated seconds"); quit(1))
	run.call_deferred()

func run() -> void:
	var main = load("res://scenes/duel.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var rival = main.get_node("Rival")
	var player = main.get_node("Player")
	var ai = rival.get_node("DriverInput")
	var match_node = main.get_node("MatchController")
	player.get_node("DamageReceiver").destroyed.connect(func(): deaths += 1)
	rival.get_node("Blaster").shot_fired.connect(func(): shots += 1)
	var upright: int = 0
	var distance: float = 0.0
	var last: Vector3 = rival.position
	for i in range(7200):
		await physics_frame
		if rival.global_basis.y.dot(Vector3.UP) > 0.75:
			upright += 1
		distance += rival.position.distance_to(last)
		last = rival.position
	await process_frame
	print("Default duel 60s: distance=", distance, " upright_frames=", upright, " resets=", ai.reset_count, " shots=", shots, " player_deaths=", deaths, " AI=", ai.state, " score=", match_node.player_score, ":", match_node.rival_score)
	var passed: bool = distance > 50.0 and upright > 6800 and ai.reset_count < 3 and shots > 5 and deaths >= 1
	passed = passed and match_node.rival_score == deaths and match_node.player_score == 0
	passed = passed and ((deaths < match_node.elimination_target and match_node.state == 0) or (deaths >= match_node.elimination_target and match_node.state == 1 and match_node.result == 2))
	print("Rival soak: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
