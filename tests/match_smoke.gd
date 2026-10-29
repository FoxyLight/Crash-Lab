extends SceneTree
const TickDamage = preload("res://tests/fixtures/tick_damage.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")
const Flash = preload("res://scripts/weapons/hit_flash.gd")
var main
var match_node
var player
var rival
var player_health
var rival_health
var failures: int = 0

func _initialize() -> void:
	create_timer(120.0, true, true).timeout.connect(func(): push_error("Match suite timeout"); quit(1))
	run.call_deferred()

func run() -> void:
	await fixture(3)
	check(match_node.state == 0 and match_node.result == 0 and match_node.player_score == 0 and match_node.rival_score == 0, "fresh duel starts Playing with zero scores and no result")
	check(main.get_node("MatchHUD").scoreboard.text.contains("First to 3"), "HUD shows configured objective and scores")
	var playing_id: int = main.get_instance_id()
	key_restart(true)
	await ticks(3)
	key_restart(false)
	check(main.get_instance_id() == playing_id and match_node.state == 0, "restart input is ignored while the match is Playing")
	player_health.take_damage(20.0)
	Input.action_press("reset_vehicle")
	await ticks(3)
	Input.action_release("reset_vehicle")
	check(player_health.health == 80.0 and match_node.rival_score == 0 and match_node.player_score == 0 and match_node.state == 0, "manual vehicle recovery does not heal, score, or restart match")
	rival_health.take_damage(10000.0)
	rival_health.take_damage(10000.0)
	rival_health.destroyed.emit()
	await ticks(3)
	check(match_node.player_score == 1 and match_node.rival_score == 0 and match_node.state == 0, "valid destruction scores exactly once despite repeated damage/signals")
	await ticks(45)
	check(not rival_health.is_destroyed and rival_health.health == 120.0 and rival.driver.controls_enabled and rival.combat_active and rival.get_node("Blaster").firing_enabled, "non-final elimination restores health, controls, and combat after safe respawn")
	check(match_node.player_score == 1, "later frames and respawn do not duplicate score")
	rival_health.take_damage(10000.0)
	await ticks(45)
	check(match_node.player_score == 2 and match_node.state == 0, "second independent destruction scores again without ending early")
	var bullet := Projectile.new()
	bullet.velocity = Vector3.FORWARD
	main.add_child(bullet)
	bullet.position = Vector3(0, 20, 0)
	var flash := Flash.new()
	main.add_child(flash)
	rival.driver.reverse_remaining = 1.0
	rival.driver.reset_requested = true
	rival_health.take_damage(10000.0)
	await ticks(4)
	check(match_node.state == 1 and match_node.result == 1 and match_node.player_score == 3, "default third elimination ends in Victory")
	check(main.get_node("MatchHUD").result_panel.visible and main.get_node("MatchHUD").result_label.text.contains("VICTORY") and not main.get_node("CombatHUD").visible, "result overlay shows victory and hides stale respawn HUD")
	check(get_nodes_in_group("projectiles").is_empty() and get_nodes_in_group("combat_effects").is_empty(), "match completion removes active projectiles and effects")
	check(player.freeze and rival.freeze and not player.driver.controls_enabled and not rival.driver.controls_enabled and not rival.driver.reset_requested, "finished match freezes both vehicles and cancels commands/resets")
	var old_player_hp: float = player_health.health
	var old_rival_hp: float = rival_health.health
	var player_generation: int = player.reset_generation
	var rival_generation: int = rival.reset_generation
	Input.action_press("accelerate")
	Input.action_press("fire_weapon")
	Input.action_press("reset_vehicle")
	player_health.take_damage(10000.0)
	rival_health.destroyed.emit()
	player.get_node("Blaster")._fire()
	await ticks(600)
	Input.action_release("accelerate")
	Input.action_release("fire_weapon")
	Input.action_release("reset_vehicle")
	check(player_health.health == old_player_hp and rival_health.health == old_rival_hp and rival_health.is_destroyed and not player_health.combat_active and not rival_health.combat_active, "finished health ignores damage and cannot respawn after countdown")
	check(player.driver.throttle == 0.0 and not player.driver.fire_requested and not rival.driver.fire_requested and get_nodes_in_group("projectiles").is_empty(), "gameplay buttons and direct weapon calls cannot restart finished combat")
	check(player.reset_generation == player_generation and rival.reset_generation == rival_generation and match_node.player_score == 3 and match_node.rival_score == 0, "recovery generations and final score stay stable after completion")
	# Enter restart works independently of disabled vehicle input.
	var old_id: int = main.get_instance_id()
	key_restart(true)
	await wait_for_reload(old_id)
	check(main.get_instance_id() != old_id and match_node.state == 0 and match_node.player_score == 0 and match_node.rival_score == 0, "Enter restarts a finished match with fresh scores and Playing state")
	check(player_health.health == 100.0 and rival_health.health == 120.0 and player.position.distance_to(Vector3(-22, 1.25, 28)) < 0.2 and rival.position.distance_to(Vector3(22, 1.25, -28)) < 0.2, "restart restores both full-health vehicles at original spawns")
	check(player.driver.controls_enabled and rival.driver.controls_enabled and player.combat_active and rival.combat_active and rival.driver.stuck_time < 0.1 and rival.driver.recovery_attempts == 0 and rival.driver.reset_count == 0 and rival.get_node("Blaster").cooldown == 0.0, "restart restores clean AI, weapon, and input lifecycle state")
	check(not main.get_node("MatchHUD").result_panel.visible and get_nodes_in_group("projectiles").is_empty() and get_nodes_in_group("combat_effects").is_empty(), "restart removes old result overlay, projectiles, and effects")
	# Keep Enter held through another finish: a deliberate release is required.
	quiet_ai()
	match_node.elimination_target = 1
	rival_health.take_damage(10000.0)
	await ticks(8)
	check(main.get_instance_id() != old_id and match_node.state == 1 and not match_node.restart_requested, "held restart cannot reload repeatedly or skip the next result")
	key_restart(false)
	await ticks(2)
	old_id = main.get_instance_id()
	controller_restart(true)
	await wait_for_reload(old_id)
	controller_restart(false)
	check(main.get_instance_id() != old_id and match_node.state == 0, "controller Start restarts while gameplay controls are disabled")
	# Repeat real scene reloads and check connections do not accumulate.
	var clean_cycles := true
	for cycle in range(3):
		await ticks(2)
		quiet_ai()
		match_node.elimination_target = 1
		rival_health.take_damage(10000.0)
		await ticks(3)
		old_id = main.get_instance_id()
		match_node.request_restart()
		match_node.request_restart()
		await wait_for_reload(old_id)
		clean_cycles = clean_cycles and match_node.state == 0 and match_node.player_score == 0 and rival_health.destroyed.get_connections().size() == 1 and match_node.score_changed.get_connections().size() == 1
	check(clean_cycles, "repeated finish/restart cycles create exactly one scoring and HUD connection")
	await fixture(1)
	player_health.take_damage(10000.0)
	await ticks(3)
	check(match_node.state == 1 and match_node.result == 2 and match_node.rival_score == 1 and match_node.player_score == 0, "configured target supports Defeat")
	check(main.get_node("MatchHUD").result_label.text.contains("DEFEAT") and main.get_node("MatchHUD").result_label.text.contains("Start"), "defeat display includes final scores and controller restart")
	# One kill occurs before the match controller; one after it in the same tick.
	await fixture(1)
	schedule_damage(player_health, -20)
	schedule_damage(rival_health, 2000)
	await ticks(4)
	check(match_node.result == 3 and match_node.player_score == 1 and match_node.rival_score == 1, "same-tick destructions across physics priorities award both points and Draw")
	check(main.get_node("MatchHUD").result_label.text.contains("DRAW"), "draw has a clear result display")
	await fixture(1)
	schedule_damage(rival_health, -20)
	schedule_damage(player_health, 2000)
	await ticks(4)
	check(match_node.result == 3 and match_node.player_score == 1 and match_node.rival_score == 1, "reversing simultaneous event order preserves Draw")
	await fixture(2)
	rival_health.take_damage(10000.0)
	await ticks(45)
	schedule_damage(rival_health, -20)
	schedule_damage(player_health, 2000)
	await ticks(4)
	check(match_node.result == 1 and match_node.player_score == 2 and match_node.rival_score == 1, "simultaneous destruction awards both points but only the participant reaching target wins")
	# Training has no match controller and retains continuous practice respawns.
	await remove_scene()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var training_health = main.get_node("MuscleCar/DamageReceiver")
	training_health.respawn_delay = 0.1
	var dummy = main.get_node("TestArena/TargetDummy")
	dummy.respawn_delay = 0.1
	training_health.take_damage(10000.0)
	dummy.take_damage(10000.0)
	await ticks(60)
	check(main.get_node_or_null("MatchController") == null and not training_health.is_destroyed and training_health.health == 100.0 and training_health.combat_active and not dummy.is_destroyed, "training remains continuous practice with vehicle and dummy respawns")
	print("Match smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func fixture(goal: int) -> void:
	await remove_scene()
	main = load("res://scenes/duel.tscn").instantiate()
	main.get_node("MatchController").elimination_target = goal
	root.add_child(main)
	current_scene = main
	bind_scene()
	quiet_ai()
	for receiver in [player_health, rival_health]:
		receiver.respawn_delay = 0.1
		receiver.spawn_protection = 0.0
	await ticks(2)

func quiet_ai() -> void:
	rival.driver.set_physics_process(false)
	rival.driver.clear_commands()

func bind_scene() -> void:
	main = current_scene
	match_node = main.get_node("MatchController")
	player = main.get_node("Player")
	rival = main.get_node("Rival")
	player_health = player.get_node("DamageReceiver")
	rival_health = rival.get_node("DamageReceiver")

func remove_scene() -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await ticks(2)

func schedule_damage(receiver: Node, priority: int) -> void:
	var event := TickDamage.new()
	event.receiver = receiver
	event.process_physics_priority = priority
	main.add_child(event)

func key_restart(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	Input.parse_input_event(event)

func controller_restart(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = pressed
	Input.parse_input_event(event)

func wait_for_reload(old_id: int) -> void:
	for i in range(30):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
			bind_scene()
			return
	check(false, "scene restart completes within 30 process frames")

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
