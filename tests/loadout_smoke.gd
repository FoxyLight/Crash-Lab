extends SceneTree
const Bank = preload("res://scripts/audio/sound_bank.gd")
var main
var player
var rival
var loadout
var blaster
var cannon
var shots: Array = []
var cues: Array[StringName] = []
var failures: int = 0

func _initialize() -> void:
	create_timer(120.0, true, true).timeout.connect(func(): push_error("Loadout suite timeout"); quit(1))
	run.call_deferred()

func run() -> void:
	main = load("res://scenes/duel.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	bind_scene()
	rival.driver.set_physics_process(false)
	rival.driver.clear_commands()
	blaster.shot_fired.connect(func(): shots.append([Engine.get_physics_frames(), 0]))
	cannon.shot_fired.connect(func(): shots.append([Engine.get_physics_frames(), 1]))
	main.get_node("CombatAudio").cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
	await ticks(180)
	check(loadout.selected_index == 0 and blaster.selected and not cannon.selected and rival.get_node_or_null("HeavyCannon") == null, "player starts with blaster and rival retains only its blaster")
	check(blaster.fire_rate == 7.0 and blaster.projectile_damage == 20.0 and blaster.projectile_speed == 110.0 and rival.get_node("Blaster").projectile_damage == 10.0, "approved player and rival weapon tuning is preserved")
	check(cannon.fire_rate == 0.8 and cannon.projectile_damage == 80.0 and cannon.projectile_speed == 65.0 and cannon.projectile_lifetime == 2.5, "cannon exposes the specified starting balance")
	key(KEY_Q, true)
	await ticks(3)
	check(loadout.selected_index == 1 and cannon.visible and not blaster.visible, "Q selects and shows only the cannon")
	await ticks(10)
	check(loadout.selected_index == 1, "held cycle does not repeatedly switch")
	key(KEY_Q, false)
	key(KEY_1, true)
	await ticks(2)
	key(KEY_1, false)
	check(loadout.selected_index == 0, "mapped 1 selects blaster directly")
	key(KEY_2, true)
	await ticks(2)
	key(KEY_2, false)
	check(loadout.selected_index == 1, "mapped 2 selects cannon directly")
	pad(true)
	await ticks(2)
	check(loadout.selected_index == 0, "controller north face cycles selection")
	await ticks(8)
	check(loadout.selected_index == 0, "held controller cycle is release gated")
	pad(false)
	await ticks(2)
	key(KEY_Q, true)
	key(KEY_2, true)
	key(KEY_1, true)
	await ticks(2)
	check(loadout.selected_index == 0, "simultaneous inputs prefer slot 1, then slot 2, then cycle")
	key(KEY_Q, false)
	key(KEY_2, false)
	key(KEY_1, false)
	await ticks(2)
	key(KEY_Q, true)
	key(KEY_2, true)
	await ticks(2)
	check(loadout.selected_index == 1, "direct cannon selection wins over simultaneous cycle")
	key(KEY_Q, false)
	key(KEY_2, false)
	Input.action_press("fire_weapon")
	await ticks(3)
	Input.action_release("fire_weapon")
	check(shot_count(1) == 1 and shot_count(0) == 0, "only the selected cannon fires from the shared fire action")
	var bullet = get_nodes_in_group("projectiles")[0]
	check(bullet.damage == 80.0 and bullet.velocity.length() > 64.9 and bullet.visual_size == Vector3(0.3, 0.3, 1.0) and bullet.color == cannon.projectile_color, "heavy shot carries its damage, speed, violet color, and larger visual")
	check(cues.count(&"heavy_shot") == 1 and Bank.get_stream(&"heavy_shot").data != Bank.get_stream(&"player_shot").data, "cannon dispatches its distinct lower shot cue")
	var cooldown: float = cannon.cooldown
	loadout.select_weapon(0)
	await ticks(30)
	check(cannon.cooldown > 0.0 and cannon.cooldown < cooldown - 0.2, "cannon cooldown continues while holstered")
	loadout.select_weapon(1)
	Input.action_press("fire_weapon")
	await ticks(12)
	check(shot_count(1) == 1, "switching back cannot bypass remaining cannon cooldown")
	loadout.select_weapon(0)
	await ticks(30)
	loadout.select_weapon(1)
	await ticks(160)
	Input.action_release("fire_weapon")
	check(shot_count(0) > 0 and shot_count(1) >= 2, "holding fire follows the selected weapon through switches")
	var unique_ticks: Dictionary = {}
	var exclusive := true
	for shot in shots:
		if unique_ticks.has(shot[0]):
			exclusive = false
		unique_ticks[shot[0]] = true
	check(exclusive, "switching while firing never emits two player shots in one physics tick")
	await ticks(3)
	clear_projectiles()
	# Claim guard also protects an explicit switch between two fire calls in one tick.
	loadout.select_weapon(0)
	var before: int = shots.size()
	blaster._fire()
	loadout.select_weapon(1)
	cannon._fire()
	check(shots.size() == before + 1, "same-tick manual fire calls cannot fire both loadout slots")
	clear_projectiles()
	await ticks(2)
	# Real cannon projectile against a target in the clear lane ahead of the player.
	var target = load("res://scenes/targets/target_dummy.tscn").instantiate()
	target.maximum_health = 200.0
	main.add_child(target)
	target.position = Vector3(-22, 0, 10)
	await ticks(2)
	cannon.cooldown = 0.0
	Input.action_press("fire_weapon")
	await ticks(45)
	Input.action_release("fire_weapon")
	check(target.health == 120.0, "mounted cannon projectile applies exactly 80 damage on impact")
	var player_hp: float = player.get_node("DamageReceiver").health
	var muzzle_position: Vector3 = cannon.muzzle.position
	cannon.muzzle.position.z = 1.0
	cannon.cooldown = 0.0
	Input.action_press("fire_weapon")
	await ticks(50)
	Input.action_release("fire_weapon")
	cannon.muzzle.position = muzzle_position
	check(target.health == 40.0 and player.get_node("DamageReceiver").health == player_hp, "cannon excludes both shooter chassis and roof hurtbox")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.1)
	collider.shape = shape
	wall.add_child(collider)
	main.add_child(wall)
	wall.position = Vector3(-22, 1.5, 20)
	await ticks(2)
	cannon.projectile_speed = 20000.0
	cannon.cooldown = 0.0
	Input.action_press("fire_weapon")
	await ticks(4)
	Input.action_release("fire_weapon")
	check(target.health == 40.0 and get_nodes_in_group("projectiles").is_empty(), "thin solid cover blocks even a high-speed cannon shot")
	cannon.projectile_speed = 65.0
	wall.queue_free()
	await ticks(2)
	cannon.projectile_lifetime = 0.05
	cannon.cooldown = 0.0
	Input.action_press("fire_weapon")
	await ticks(12)
	Input.action_release("fire_weapon")
	check(get_nodes_in_group("projectiles").is_empty() and target.health == 40.0, "cannon misses clean up at lifetime without distant damage")
	cannon.projectile_lifetime = 2.5
	player.get_node("DamageReceiver").take_damage(10.0)
	cooldown = cannon.cooldown
	key(KEY_R, true)
	await ticks(3)
	key(KEY_R, false)
	check(loadout.selected_index == 1 and cannon.cooldown > cooldown - 0.1 and cannon.cooldown <= cooldown and player.get_node("DamageReceiver").health == player_hp - 10.0, "manual recovery preserves selection, health, and running cooldown")
	check(player.get_node("LoadoutHUD").readout.text.contains("HEAVY CANNON") and player.get_node("LoadoutHUD").readout.text.contains("COOLDOWN"), "HUD shows active weapon and remaining cooldown")
	var health = player.get_node("DamageReceiver")
	health.respawn_delay = 0.5
	health.take_damage(10000.0)
	before = shots.size()
	key(KEY_Q, true)
	Input.action_press("fire_weapon")
	await ticks(10)
	check(loadout.selected_index == 1 and shots.size() == before, "destroyed player ignores switching and firing")
	key(KEY_Q, false)
	Input.action_release("fire_weapon")
	await ticks(100)
	check(not health.is_destroyed and loadout.selected_index == 0 and blaster.selected and not cannon.selected, "ordinary respawn returns to blaster without creating a new loadout")
	loadout.select_weapon(1)
	main.get_node("CombatAudio").set_muted(true)
	var cue_count: int = cues.size()
	cannon.cooldown = 0.0
	Input.action_press("fire_weapon")
	await ticks(3)
	Input.action_release("fire_weapon")
	check(cues.size() == cue_count and shot_count(1) > 0, "existing mute suppresses heavy audio without blocking firing")
	main.get_node("CombatAudio").set_muted(false)
	clear_projectiles()
	loadout.select_weapon(0)
	main.get_node("MatchController").elimination_target = 1
	rival.get_node("DamageReceiver").take_damage(10000.0)
	await ticks(4)
	before = shots.size()
	key(KEY_2, true)
	Input.action_press("fire_weapon")
	loadout.select_weapon(1)
	blaster._fire()
	cannon._fire()
	await ticks(10)
	check(not loadout.active and loadout.selected_index == 0 and not blaster.firing_enabled and not cannon.firing_enabled and shots.size() == before, "finished match disables selection and both active and holstered weapons")
	key(KEY_2, false)
	Input.action_release("fire_weapon")
	var clean := true
	for cycle in range(2):
		var old_id: int = main.get_instance_id()
		main.get_node("MatchController").request_restart()
		for i in range(30):
			await process_frame
			if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
				break
		bind_scene()
		clean = clean and main.get_instance_id() != old_id and loadout.selected_index == 0 and loadout.active and blaster.cooldown == 0.0 and cannon.cooldown == 0.0 and blaster.firing_enabled and cannon.firing_enabled
		if cycle == 0:
			loadout.select_weapon(1)
			main.get_node("MatchController").elimination_target = 1
			rival.get_node("DamageReceiver").take_damage(10000.0)
			await ticks(4)
	check(clean, "repeated full restart rebuilds default selection and clean independent cooldowns")
	main.queue_free()
	await ticks(2)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("MuscleCar")
	player.get_node("Loadout").select_weapon(1)
	check(player.get_node("HeavyCannon").selected and main.get_node("EnemyTurret").get_node_or_null("HeavyCannon") == null and main.get_node_or_null("MatchController") == null, "training supports player switching without changing turret or practice rules")
	print("Loadout smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func bind_scene() -> void:
	main = current_scene
	player = main.get_node("Player")
	rival = main.get_node("Rival")
	loadout = player.get_node("Loadout")
	blaster = player.get_node("Blaster")
	cannon = player.get_node("HeavyCannon")

func shot_count(slot: int) -> int:
	return shots.filter(func(shot): return shot[1] == slot).size()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func pad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)

func clear_projectiles() -> void:
	for bullet in get_nodes_in_group("projectiles"):
		bullet.queue_free()

func ticks(amount: int) -> void:
	for i in amount:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
