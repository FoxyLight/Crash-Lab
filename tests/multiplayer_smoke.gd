extends SceneTree
## Synthetic raw events exercise production routing; virtual inventories exercise
## the same assignment method as hotplug. Physical Windows pads remain manual.
const Router = preload("res://scripts/multiplayer/local_input_router.gd")
const Sparks = preload("res://scripts/effects/crash_sparks.gd")
var scene
var router
var p1
var p2
var match_node
var checks: int = 0
var failures: int = 0
var shots: Array[int] = [0, 0]
var cues: Array[StringName] = []

func _initialize() -> void:
	create_timer(120.0, true, true).timeout.connect(func(): push_error("Multiplayer checks timed out"); quit(1))
	_run.call_deferred()

func _run() -> void:
	Router.two_gamepads = false
	Router.saved_devices = [-1, -1]
	await fresh()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/duel.tscn", "AI duel remains the configured launch mode")
	check(scene.find_children("*", "RigidBody3D", true, false).size() == 2 and scene.get_node_or_null("Rival") == null, "local arena has exactly two human chassis and no AI rival")
	check(p1.get_node("DriverInput").router == router and p2.get_node("DriverInput").router == router, "both providers explicitly reference the scene-local router")
	check(p1.mass == 1400 and p2.mass == 1400 and p1.engine_force == 22000 and p2.maximum_speed == 55 and p1.steering_speed_reference == 42, "shared approved v0.9 chassis tuning is preserved")
	check(p1.get_node("DamageReceiver").maximum_health == 100 and p2.get_node("DamageReceiver").maximum_health == 100 and p1.get_node("HeavyCannon").projectile_damage == p2.get_node("HeavyCannon").projectile_damage, "both humans have equal health, protection and player weapon defaults")
	check(scene.views.size() == 2 and scene.views[0].world_3d == scene.views[1].world_3d and scene.views[0].world_3d == p1.get_world_3d(), "two render views share the single physical World3D")
	check(scene.cameras[0].target == p1 and scene.cameras[1].target == p2 and scene.cameras[0].get_viewport() != scene.cameras[1].get_viewport(), "each camera follows its own player in its own viewport")
	check(not scene.views[0].audio_listener_enable_3d and not scene.views[1].audio_listener_enable_3d and scene.listener.is_current(), "one shared listener serves both views without duplicate viewport audio")
	router.assign_devices([3])
	await ticks(3)
	check(router.devices == [-1, 3], "default keyboard plus first pad supports a nonzero device ID")
	var start1: Vector3 = p1.position
	var start2: Vector3 = p2.position
	key(KEY_W, true)
	key(KEY_F, true)
	await ticks(120)
	check(p1.position.distance_to(start1) > 3.0 and p2.position.distance_to(start2) < 0.3, "native keyboard events physically move only Player 1")
	check(shots[0] > 4 and shots[1] == 0, "keyboard firing reaches only Player 1 weapon")
	check(scene.cameras[0].fov > scene.cameras[1].fov and scene.cameras[0].speed_fov_increase == 10 and scene.cameras[1].base_fov == 75, "speed FOV reacts independently while preserving both approved camera defaults")
	key(KEY_W, false)
	key(KEY_F, false)
	var generation1: int = p1.reset_generation
	var generation2: int = p2.reset_generation
	key(KEY_R, true)
	await ticks(6)
	key(KEY_R, false)
	check(p1.reset_generation == generation1 + 1 and p2.reset_generation == generation2, "keyboard recovery resets only Player 1")
	key(KEY_2, true)
	await ticks(2)
	key(KEY_2, false)
	check(p1.get_node("Loadout").selected_index == 1 and p2.get_node("Loadout").selected_index == 0, "keyboard direct weapon selection stays with Player 1")
	key(KEY_1, true)
	await ticks(2)
	key(KEY_1, false)
	await place(p1, Vector3(-22, 1.25, 28))
	start1 = p1.position
	var first_shots: int = shots[0]
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 0.7)
	button(3, JOY_BUTTON_RIGHT_SHOULDER, true)
	await ticks(120)
	check(p2.position.distance_to(start2) > 1.0 and p1.position.distance_to(start1) < 0.3, "Player 2 pad physically moves only Player 2")
	check(shots[1] > 3 and shots[0] == first_shots and p1.get_node("DriverInput").throttle == 0, "Player 2 fire and throttle do not leak into Player 1")
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 0)
	button(3, JOY_BUTTON_RIGHT_SHOULDER, false)
	generation1 = p1.reset_generation
	generation2 = p2.reset_generation
	button(3, JOY_BUTTON_DPAD_UP, true)
	await ticks(6)
	button(3, JOY_BUTTON_DPAD_UP, false)
	check(p2.reset_generation == generation2 + 1 and p1.reset_generation == generation1, "pad recovery resets only Player 2")
	router.set_two_gamepads(true)
	router.assign_devices([3, 9])
	await ticks(3)
	check(router.devices == [3, 9], "two pads receive separate stable slots with noncontiguous IDs")
	key(KEY_W, true)
	await ticks(3)
	check(p1.get_node("DriverInput").throttle == 0 and p2.get_node("DriverInput").throttle == 0, "keyboard driving is ignored in two-controller mode")
	key(KEY_W, false)
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 0.7)
	axis(3, JOY_AXIS_LEFT_X, -0.5)
	axis(9, JOY_AXIS_TRIGGER_LEFT, 0.5)
	axis(9, JOY_AXIS_LEFT_X, 0.6)
	button(3, JOY_BUTTON_A, true)
	await ticks(3)
	check(p1.get_node("DriverInput").throttle > 0.5 and p1.get_node("DriverInput").throttle < 0.8 and p1.get_node("DriverInput").steering < -0.3 and p1.get_node("DriverInput").handbrake, "Player 1 preserves analog trigger, steering and independent handbrake")
	check(p2.get_node("DriverInput").brake > 0.3 and p2.get_node("DriverInput").steering > 0.4 and not p2.get_node("DriverInput").handbrake, "Player 2 preserves separate analog brake/reverse and steering")
	axis(3, JOY_AXIS_LEFT_X, 0.1)
	await ticks(2)
	check(p1.get_node("DriverInput").steering == 0, "controller steering applies the existing 0.15 deadzone")
	neutral()
	button(3, JOY_BUTTON_Y, true)
	await ticks(2)
	check(p1.get_node("Loadout").selected_index == 1 and p2.get_node("Loadout").selected_index == 0, "pad weapon cycle selects only its owner's cannon")
	for i in 12:
		button(3, JOY_BUTTON_Y, true)
		await ticks(1)
	check(p1.get_node("Loadout").selected_index == 1, "duplicate or held cycle events cannot repeatedly switch weapons")
	button(3, JOY_BUTTON_Y, false)
	button(3, JOY_BUTTON_Y, true)
	button(9, JOY_BUTTON_Y, true)
	await ticks(2)
	check(p1.get_node("Loadout").selected_index == 0 and p2.get_node("Loadout").selected_index == 1, "fresh cycle presses switch both independent loadouts")
	neutral()
	await place(p1, Vector3(-50, 1.25, 50))
	await place(p2, Vector3(50, 1.25, -50), PI)
	start1 = p1.position
	start2 = p2.position
	shots = [0, 0]
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 1)
	axis(9, JOY_AXIS_TRIGGER_RIGHT, 1)
	button(3, JOY_BUTTON_RIGHT_SHOULDER, true)
	button(9, JOY_BUTTON_RIGHT_SHOULDER, true)
	await ticks(120)
	check(p1.position.distance_to(start1) > 3 and p2.position.distance_to(start2) > 3 and shots[0] >= 6 and shots[1] >= 1, "both humans physically drive and fire simultaneously")
	check(p1.get_node("Blaster").cooldown < 0.15 and p2.get_node("HeavyCannon").cooldown > 0.1, "blaster and cannon cooldowns remain independently owned")
	neutral()
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 1)
	button(3, JOY_BUTTON_RIGHT_SHOULDER, true)
	p2.freeze = true
	button(9, JOY_BUTTON_DPAD_UP, true)
	await ticks(2)
	router.assign_devices([9])
	await ticks(3)
	check(router.devices == [-1, 9] and p1.get_node("DriverInput").throttle == 0 and not p1.get_node("DriverInput").fire_requested and p2.get_node("DriverInput").reset_requested, "disconnect stops its owner without stealing Player 2 pad or cancelling its pending recovery")
	button(9, JOY_BUTTON_DPAD_UP, false)
	p2.get_node("DriverInput").reset_requested = false
	p2.freeze = false
	axis(3, JOY_AXIS_TRIGGER_RIGHT, 1)
	await ticks(2)
	check(p1.get_node("DriverInput").throttle == 0, "events from disconnected or unassigned IDs are ignored")
	router.assign_devices([9, 14])
	button(14, JOY_BUTTON_RIGHT_SHOULDER, true)
	await ticks(5)
	check(router.devices == [14, 9] and not p1.get_node("DriverInput").fire_requested, "reconnect fills only empty slot and requires released controls before joining")
	button(14, JOY_BUTTON_RIGHT_SHOULDER, false)
	await ticks(2)
	button(14, JOY_BUTTON_RIGHT_SHOULDER, true)
	await ticks(2)
	check(p1.get_node("DriverInput").fire_requested and not p2.get_node("DriverInput").fire_requested, "reconnected pad works after neutral and remains independently routed")
	neutral()
	await hud_and_effect_checks()
	await scoring_checks()
	await dead_input_checks()
	await spawn_checks()
	await restart_checks()
	if is_instance_valid(scene):
		scene.queue_free()
		await ticks(2)
	print("Multiplayer smoke checks: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func hud_and_effect_checks() -> void:
	await fresh()
	p1.get_node("DamageReceiver").take_damage(10)
	p2.get_node("DamageReceiver").take_damage(35)
	p1.get_node("Loadout").select_weapon(1)
	await ticks(3)
	check(scene.huds[0].bar.value == 90 and scene.huds[1].bar.value == 65, "each compact HUD tracks its own health")
	check("HEAVY CANNON" in scene.huds[0].weapon_status.text and "BLASTER" in scene.huds[1].weapon_status.text, "each HUD displays its own selected weapon")
	check(scene.huds[0].flash > 0 and scene.huds[1].flash > 0 and scene.huds[0].vehicle != scene.huds[1].vehicle, "damage flashes belong to separate player HUDs")
	await place(p2, Vector3(-45, 1.25, 10))
	await ticks(3)
	check(p2.get_node("DamageReceiver").health == 90 and scene.huds[1].repair_remaining > 0 and scene.huds[0].repair_remaining == 0, "repair pickup and feedback reach only the collecting player's HUD")
	for camera in scene.cameras:
		camera.clear_impact()
	cues.clear()
	var data := {"vehicle": p1, "collider": p2, "severity": 3, "position": p1.position, "normal": Vector3.BACK, "type": "vehicle"}
	p1.get_node("ImpactDetector").impact_detected.emit(data)
	check(scene.cameras[0].shake_remaining > 0 and scene.cameras[1].shake_remaining > 0, "one vehicle-pair crash reacts in both involved cameras")
	check(cues.count(&"crash_major") == 1, "two viewports do not duplicate collision sound dispatch")
	var spark := Sparks.new()
	spark.severity = 3
	spark.crossed_streaks = true
	scene.add_child(spark)
	check(spark.streak_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 216 and get_nodes_in_group("crash_effects").size() == 1, "one simulated spark burst uses crossed streak geometry visible to both cameras")
	await ticks(85)
	check(get_nodes_in_group("crash_effects").is_empty(), "shared spark lifetime still expires before respawn")
	var previous: Vector2i = scene.views[0].size
	root.size = Vector2i(960, 640)
	await ticks(5)
	check(scene.views[0].size.x > 0 and scene.views[0].size == scene.views[1].size and scene.huds[0].size.y > 200, "resized window keeps two equal views and valid half-height HUDs")
	root.size = Vector2i(1280, 720)
	await ticks(5)
	check(scene.views[0].size.x >= previous.x and scene.huds[0].bar.value == 90, "resizing back preserves player presentation and health state")
	await fresh()
	await place(p1, Vector3(50, 1.25, 40))
	await place(p2, Vector3(50, 1.25, 28), PI)
	var impacts := [0]
	for actor in [p1, p2]:
		actor.get_node("ImpactDetector").impact_detected.connect(func(_data): impacts[0] += 1)
	cues.clear()
	p1.linear_velocity = Vector3(0, 0, -55)
	p2.linear_velocity = Vector3(0, 0, 55)
	await ticks(30)
	check(impacts[0] == 1 and p1.position.z > p2.position.z and p1.position.distance_to(p2.position) > 4, "actual local-world 55 m/s head-on stops both chassis and emits one canonical crash")
	check(scene.cameras[0].shake_remaining > 0 and scene.cameras[1].shake_remaining > 0 and cues.count(&"crash_major") == 1, "actual shared collision reaches both cameras and one sound observer")

func scoring_checks() -> void:
	await fresh()
	await place(p1, Vector3(50, 1.25, 20))
	await place(p2, Vector3(50, 1.25, -2), PI)
	p1.freeze = true
	p2.freeze = true
	p2.get_node("DamageReceiver").health = 20
	p1.get_node("Blaster")._fire()
	await ticks(45)
	check(p2.get_node("DamageReceiver").is_destroyed and p2.get_node("DamageReceiver").get_death_source() == p1 and match_node.player_score == 1, "actual Player 1 projectile carries source through hurtbox and earns correct credit")
	p2.get_node("DamageReceiver").take_damage_from(1000, p1)
	await ticks(3)
	check(match_node.player_score == 1 and match_node.rival_score == 0, "destroyed body cannot award another elimination for the same life")
	await fresh()
	await place(p1, Vector3(50, 1.25, 20))
	await place(p2, Vector3(50, 1.25, -2), PI)
	p1.freeze = true
	p2.freeze = true
	p1.get_node("DamageReceiver").health = 20
	match_node.elimination_target = 1
	p2.get_node("Blaster")._fire()
	await ticks(45)
	check(match_node.rival_score == 1 and match_node.player_score == 0 and scene.result_label.text.begins_with("PLAYER 2 WINS"), "actual Player 2 projectile earns Player 2 credit and the correct result")
	await fresh()
	p1.get_node("DamageReceiver").take_damage_from(10, p2)
	p1.get_node("DamageReceiver").take_damage(1000)
	await ticks(4)
	check(match_node.player_score == 0 and match_node.rival_score == 0 and p1.get_node("DamageReceiver").get_death_source() == null, "unattributed environmental lethal hit never reuses a previous attacker")
	await fresh()
	p1.get_node("DamageReceiver").take_damage_from(1000, p1)
	await ticks(4)
	check(match_node.player_score == 0 and match_node.rival_score == 0, "self-inflicted destruction never awards the opponent an undeserved point")
	await fresh()
	match_node.elimination_target = 1
	p1.get_node("DamageReceiver").take_damage_from(1000, p2)
	p2.get_node("DamageReceiver").take_damage_from(1000, p1)
	await ticks(4)
	check(match_node.state == 1 and match_node.result == 3 and match_node.player_score == 1 and match_node.rival_score == 1, "same-physics-tick attributed eliminations preserve draw handling")
	check(scene.result_label.text.begins_with("DRAW") and p1.freeze and p2.freeze and not p1.get_node("Blaster").firing_enabled and not p2.get_node("HeavyCannon").firing_enabled, "draw freezes both humans and stops both loadouts with one clear result")

func dead_input_checks() -> void:
	await fresh()
	router.set_two_gamepads(true)
	router.assign_devices([3, 9])
	await ticks(3)
	var health = p1.get_node("DamageReceiver")
	health.respawn_delay = 0.1
	health.take_damage_from(1000, p1)
	button(3, JOY_BUTTON_Y, true)
	button(3, JOY_BUTTON_DPAD_UP, true)
	await ticks(3)
	check(p1.get_node("Loadout").selected_index == 0 and p1.reset_generation == 0, "dead human cannot switch weapons or bypass respawn with a recovery edge")
	await ticks(40)
	button(3, JOY_BUTTON_Y, true)
	await ticks(3)
	check(not health.is_destroyed and p1.get_node("Loadout").selected_index == 0, "cycle held through respawn does not become a fresh weapon press")
	button(3, JOY_BUTTON_Y, false)
	button(3, JOY_BUTTON_DPAD_UP, false)
	button(3, JOY_BUTTON_Y, true)
	await ticks(2)
	check(p1.get_node("Loadout").selected_index == 1, "a newly pressed cycle works after respawn")
	neutral()

func spawn_checks() -> void:
	await fresh()
	await place(p1, Vector3(50, 1.25, 40))
	await place(p2, Vector3(-22, 1.25, 28))
	p2.freeze = true
	var health = p1.get_node("DamageReceiver")
	health.respawn_delay = 0.1
	health.alternate_spawn_delay = 0.25
	health.take_damage_from(1000, p2)
	await ticks(20)
	check(health.is_destroyed and health.waiting_for_spawn and not p1.get_node("DriverInput").controls_enabled, "occupied primary spawn defers health and input while fallback delay runs")
	await ticks(80)
	check(not health.is_destroyed and health.health == 100 and p1.position.distance_to(p2.position) > 10 and p1.position.distance_to(Vector3(-55, 0.87, 55)) < 2, "blocked spawn chooses first supported and unoccupied alternate deterministically")
	check(health.protection_remaining > 0 and p1.get_node("DriverInput").controls_enabled and health.get_death_source() == null, "confirmed alternate respawn restores health, controls, shield and clean attribution")
	health.take_damage_from(20, p2)
	check(health.health == 100, "existing protection rejects attributed damage after alternate respawn")
	await fresh()
	await place(p1, Vector3(50, 1.25, 40))
	health = p1.get_node("DamageReceiver")
	health.respawn_delay = 0.1
	health.alternate_spawn_delay = 0.1
	var blocks: Array[Node] = []
	blocks.append(block(Vector3(-22, 2, 28)))
	for point in p1.alternate_spawn_points:
		blocks.append(block(Vector3(point.x, 2, point.z)))
	await ticks(3)
	health.take_damage_from(1000, p2)
	await ticks(180)
	check(health.is_destroyed and health.waiting_for_spawn and p1.reset_generation == 0 and not p1.get_node("DriverInput").fire_requested, "all occupied candidates defer safely without overlap, healing or firing")
	blocks[1].queue_free()
	await ticks(30)
	check(not health.is_destroyed and p1.position.distance_to(Vector3(-55, 0.87, 55)) < 2, "deferred respawn resumes once a validated alternative becomes clear")

func restart_checks() -> void:
	await fresh()
	router.set_two_gamepads(true)
	router.assign_devices([3, 9])
	await ticks(3)
	key(KEY_M, true)
	key(KEY_M, false)
	await ticks(2)
	check(scene.get_node("CombatAudio").session_muted, "one routed mute command changes the shared audio session once")
	for repetition in range(2):
		var spark := Sparks.new()
		scene.add_child(spark)
		p1.get_node("Blaster")._fire()
		match_node.elimination_target = 1
		p1.get_node("DamageReceiver").take_damage_from(1000, p2)
		await ticks(4)
		check(scene.result_label.text.begins_with("PLAYER 2 WINS") and get_nodes_in_group("projectiles").is_empty() and get_nodes_in_group("crash_effects").is_empty(), "completed local match names Player 2 and clears shared projectiles/effects")
		var old_id: int = scene.get_instance_id()
		button(3, JOY_BUTTON_START, true)
		button(9, JOY_BUTTON_START, true)
		await ticks(8)
		scene = current_scene
		bind_scene()
		check(scene.get_instance_id() != old_id and match_node.player_score == 0 and match_node.rival_score == 0 and scene.huds.size() == 2, "simultaneous deliberate restart commands reload exactly one fresh match with both HUDs")
		var new_id: int = scene.get_instance_id()
		await ticks(8)
		check(scene.get_instance_id() == new_id and router.two_gamepads and p1.get_node("DriverInput").router == router and p2.get_node("DriverInput").router == router, "restart retains selected controller setup without stale providers or another held restart")
		check(scene.get_node("CombatAudio").session_muted, "session mute remains active across local match restart")
		router.assign_devices([3, 9]) # Reinject virtual inventory; no physical pads in headless.
		await ticks(3)
		button(3, JOY_BUTTON_START, false)
		button(9, JOY_BUTTON_START, false)
		check(router.devices == [3, 9] and scene.get_node("RepairPickups/WestRepair").available and scene.huds[0].vehicle == p1 and scene.huds[1].vehicle == p2, "fresh routing, pickups and player-bound HUDs survive repeated match lifecycles")
		shots = [0, 0]

func fresh() -> void:
	if is_instance_valid(scene):
		neutral()
		scene.queue_free()
		await ticks(2)
	scene = load("res://scenes/local_duel.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	bind_scene()
	shots = [0, 0]
	cues.clear()
	p1.get_node("Blaster").shot_fired.connect(func(): shots[0] += 1)
	p1.get_node("HeavyCannon").shot_fired.connect(func(): shots[0] += 1)
	p2.get_node("Blaster").shot_fired.connect(func(): shots[1] += 1)
	p2.get_node("HeavyCannon").shot_fired.connect(func(): shots[1] += 1)
	scene.get_node("CombatAudio").set_muted(false)
	scene.get_node("CombatAudio").cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
	await ticks(180)

func bind_scene() -> void:
	router = scene.get_node("InputRouter")
	p1 = scene.get_node("Player1")
	p2 = scene.get_node("Player2")
	match_node = scene.get_node("MatchController")

func place(actor: RigidBody3D, location: Vector3, yaw: float = 0.0) -> void:
	await physics_frame # Place rigid fixtures during the physics synchronization phase.
	actor.freeze = true
	actor.global_transform = Transform3D(Basis(Vector3.UP, yaw), location)
	actor.linear_velocity = Vector3.ZERO
	actor.angular_velocity = Vector3.ZERO
	await ticks(3)
	actor.freeze = false
	await ticks(120)

func block(location: Vector3) -> Node:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 6)
	shape.shape = box
	body.add_child(shape)
	scene.add_child(body)
	body.position = location
	return body

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func axis(device: int, which: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = which
	event.axis_value = value
	router.route_event(event)

func button(device: int, which: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = which
	event.pressed = pressed
	router.route_event(event)

func neutral() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_F, KEY_SPACE, KEY_Q, KEY_R, KEY_1, KEY_2, KEY_ENTER, KEY_M]:
		key(code, false)
	for device in router.devices:
		if device < 0: continue
		for which in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			axis(device, which, 0)
		for which in Router.BUTTONS:
			button(device, which, false)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
