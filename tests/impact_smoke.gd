extends SceneTree
const Impact = preload("res://scripts/vehicles/vehicle_impact.gd")
const Bank = preload("res://scripts/audio/sound_bank.gd")
var scene: Node3D
var car
var other
var detector
var camera
var audio
var feedback
var events: Array[Dictionary] = []
var cues: Array[StringName] = []
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	create_timer(100.0, true, true).timeout.connect(func(): push_error("Impact checks timed out"); quit(1))
	_run.call_deferred()

func _run() -> void:
	await fixture(Vector3(0, 1.25, 5), Vector3(0, 1.25, 0))
	check(car.contact_monitor and car.max_contacts_reported == 16, "shared chassis enables supported contact reporting")
	check(detector.classify(1.49) == 0 and detector.classify(1.5) == 1 and detector.classify(5.0) == 2 and detector.classify(12.0) == 3, "thresholds classify closing speed in m/s at exact boundaries")
	check(detector.classify(NAN) == 0 and detector.classify(INF) == 0 and detector.classify(-5.0) == 0, "invalid and separating speeds cannot classify as crashes")
	check(not detector.exaggeration_enabled and not other.get_node("ImpactDetector").exaggeration_enabled, "extra collision impulses default off for both vehicles")
	car.linear_velocity = Vector3(0, 0, -2)
	await ticks(150)
	check(events.size() == 1 and peak() == 1, "actual low-speed rear contact emits one minor event")
	check(camera.shake_remaining == 0.0, "minor bumps do not shake camera")
	await fixture(Vector3(0, 1.25, 5), Vector3(0, 1.25, -5))
	other.rotation.y = PI
	car.linear_velocity = Vector3(0, 0, -20)
	other.linear_velocity = Vector3(0, 0, 20)
	await ticks(75)
	print("Head-on contacts: ", summarize())
	check(events.size() == 1 and peak() == 3, "two moving rigid bodies produce exactly one head-on major event")
	var head_speed: float = events[0].closing_speed if not events.is_empty() else 0.0
	check(head_speed > 30.0, "head-on severity measures opposing relative velocities")
	check(valid_data(), "contact positions, normals, velocities and closing speeds remain finite and valid")
	check(feedback.dispatch_count == 1 and cues.count(&"crash_major") == 1 and not cues.has(&"impact"), "one canonical collision dispatches feedback and distinct crash audio once")
	check(car.get_node("DamageReceiver").health == 100.0 and other.get_node("DamageReceiver").health == 120.0, "physical impacts leave both health receivers unchanged")
	check(detector.last_linear_impulse == Vector3.ZERO, "default major crash adds no extra physical impulse")
	check(car.global_basis.y.dot(Vector3.UP) > 0.7 and other.global_basis.y.dot(Vector3.UP) > 0.7, "head-on crash remains upright with approved chassis physics")
	await fixture(Vector3(-2.0, 1.25, 3), Vector3(0, 1.25, 0))
	car.linear_velocity = Vector3(4, 0, -25)
	await ticks(90)
	print("Glancing contacts: ", summarize())
	check(events.size() >= 1 and peak() < 3, "actual fast glancing sideswipe differs from head-on classification")
	check(not events.is_empty() and events[0].closing_speed < head_speed * 0.5, "tangential vehicle speed does not dominate closing severity")
	await fixture(Vector3(0, 1.25, 6), Vector3(0, 1.25, 0))
	car.linear_velocity = Vector3(0, 0, -20)
	other.linear_velocity = Vector3(0, 0, -8)
	await ticks(90)
	print("Rear-end contacts: ", summarize())
	check(events.size() == 1 and peak() == 2 and events[0].closing_speed > 5.0, "actual rear-end crash measures meaningful speed difference")
	await fixture(Vector3(-5, 1.25, 0), Vector3(0, 1.25, 0))
	detector.exaggeration_enabled = true
	other.get_node("ImpactDetector").exaggeration_enabled = true
	car.linear_velocity = Vector3(20, 0, 0)
	await ticks(60)
	check(events.size() == 1 and peak() == 3, "actual perpendicular side ram can still be major")
	check(detector.last_linear_impulse.length() > 0.0 and detector.last_linear_impulse.length() <= 700.01 and absf(detector.last_linear_impulse.y) < 0.001, "opt-in extra impulse is nonzero, capped and planar")
	check(detector.last_angular_impulse.length() <= 180.01 and detector.last_angular_impulse.x == 0.0 and detector.last_angular_impulse.z == 0.0, "opt-in angular impulse is capped and yaw only")
	check(car.global_basis.y.dot(Vector3.UP) > 0.7 and car.linear_velocity.is_finite(), "opt-in exaggeration remains upright and finite")
	await fixture(Vector3(0, 1.25, 5), Vector3(30, 1.25, 30))
	block(Vector3(0, 2, 0), Vector3(15, 4, 1))
	await ticks(3)
	car.linear_velocity = Vector3(0, 0, -22)
	car.get_node("DriverInput").throttle = 1.0
	await ticks(360)
	check(events.size() == 1 and peak() == 3 and events[0].type == "arena", "sustained powered wall contact emits one arena crash, not repeated effects")
	check(camera.shake_remaining == 0.0 and camera.h_offset == 0.0 and camera.v_offset == 0.0, "camera shake decays completely during sustained contact")
	# Explicit separation permits a second distinct ram into the same wall.
	car.freeze = true
	car.position = Vector3(0, 1.25, 5)
	car.get_node("DriverInput").throttle = 0.0
	await ticks(60)
	car.freeze = false
	await ticks(2)
	car.linear_velocity = Vector3(0, 0, -22)
	await ticks(60)
	check(events.size() == 2, "same collider rearms only after real separation delay")
	car.get_node("DriverInput").reset_requested = true
	await ticks(4)
	check(detector.pending.is_empty() and detector.last_impact.is_empty() and detector.last_linear_impulse == Vector3.ZERO, "manual recovery clears impact state and pending reactions")
	check(camera.shake_remaining == 0.0, "manual recovery clears camera shake")
	await fixture(Vector3(0, 1.25, 40), Vector3(40, 1.25, 40))
	car.get_node("DriverInput").throttle = 1.0
	await ticks(480)
	check(car.position.z < 15.0 and events.is_empty(), "actual acceleration on ordinary flat ground produces no crash events")
	# Camera bounds are independent of rendering; no game RNG is consumed.
	var data := {"vehicle": car, "collider": other, "severity": 3, "position": car.position, "normal": Vector3.RIGHT}
	camera.add_impact(data)
	await ticks(3)
	check(camera.shake_remaining > 0.0 and absf(camera.h_offset) <= 0.18 and absf(camera.v_offset) <= 0.108, "major camera reaction is brief and bounded")
	car.get_node("DamageReceiver").take_damage(1000.0)
	check(detector.contacts.is_empty() and detector.pending.is_empty() and camera.shake_remaining == 0.0, "destruction clears detector and camera state immediately")
	var before: int = detector.event_count
	car.get_node("DamageReceiver").respawn_delay = 0.1
	await ticks(420)
	check(not car.get_node("DamageReceiver").is_destroyed and detector.event_count == before and detector.last_impact.is_empty(), "safe respawn restores driving without stale impact dispatch")
	check(Bank.get_stream(&"crash_minor").data != Bank.get_stream(&"impact").data and Bank.get_stream(&"crash_major").data != Bank.get_stream(&"crash_moderate").data, "procedural crash cues differ by severity and from projectile cue")
	await duel_lifecycle()
	print("Impact smoke checks: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func fixture(a: Vector3, b: Vector3) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await ticks(2)
	events.clear()
	cues.clear()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	car = load("res://scenes/vehicles/player_car.tscn").instantiate()
	other = load("res://scenes/vehicles/rival_car.tscn").instantiate()
	car.position = a
	other.position = b
	scene.add_child(car)
	scene.add_child(other)
	for actor in [car, other]:
		actor.get_node("DriverInput").set_physics_process(false)
		actor.get_node("DriverInput").clear_commands()
		actor.get_node("Blaster").set_physics_process(false)
		actor.get_node("ImpactDetector").impact_detected.connect(func(data): events.append(data))
	detector = car.get_node("ImpactDetector")
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/camera/chase_camera.gd"))
	camera.target = car
	scene.add_child(camera)
	feedback = Node.new()
	feedback.set_script(load("res://scripts/effects/impact_feedback.gd"))
	scene.add_child(feedback)
	audio = Node3D.new()
	audio.set_script(load("res://scripts/audio/combat_audio.gd"))
	audio.player = car
	scene.add_child(audio)
	audio.set_muted(false)
	audio.cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
	await ticks(180)

func duel_lifecycle() -> void:
	scene.queue_free()
	await ticks(2)
	scene = load("res://scenes/duel.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	car = scene.get_node("Player")
	other = scene.get_node("Rival")
	detector = car.get_node("ImpactDetector")
	var match_node = scene.get_node("MatchController")
	match_node.elimination_target = 1
	var pad = scene.get_node("RepairPickups/WestRepair")
	check(pad.available and car.get_node("Loadout").selected_index == 0 and match_node.player_score == 0, "duel starts with existing pickup, weapon and scoring state")
	# Simulate an already captured event waiting for safe dispatch when match ends.
	detector.pending.append({"vehicle": car, "collider": other, "severity": 3})
	car.finish_combat()
	check(detector.pending.is_empty() and detector.contacts.is_empty(), "finish gate clears queued impacts before further dispatch")
	other.get_node("DamageReceiver").take_damage(1000.0)
	await ticks(5)
	check(match_node.state == 1 and not scene.get_node("ImpactFeedback").enabled and not pad.enabled, "match completion disables impact feedback alongside existing pickups")
	check(detector.event_count == 0 and detector.last_linear_impulse == Vector3.ZERO and get_nodes_in_group("crash_effects").is_empty(), "finished duel has no late crash event, impulse or visual effect")
	match_node.request_restart()
	await ticks(8)
	scene = current_scene
	check(scene.get_node("ImpactFeedback").enabled and scene.get_node("Player/ImpactDetector").event_count == 0 and scene.get_node("Player/ImpactDetector").pending.is_empty(), "restart creates fresh impact observer and detector state")
	check(scene.get_node("MatchController").player_score == 0 and scene.get_node("RepairPickups/WestRepair").available, "restart preserves fresh match and repair behavior")
	scene.queue_free()
	await ticks(2)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await ticks(5)
	check(scene.get_node("ImpactFeedback").enabled and scene.get_node("MuscleCar/ImpactDetector").impact_detected.get_connections().size() == 2, "training connects one visual observer and one crash audio observer")
	scene.queue_free()
	await ticks(2)

func block(location: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	scene.add_child(body)
	body.position = location

func peak() -> int:
	var value := 0
	for data in events:
		value = maxi(value, data.severity)
	return value

func valid_data() -> bool:
	for data in events:
		if not data.position.is_finite() or not data.normal.is_finite() or not data.relative_velocity.is_finite() or not is_finite(data.closing_speed) or absf(data.normal.length() - 1.0) > 0.001 or not is_instance_valid(data.collider):
			return false
	return not events.is_empty()

func summarize() -> Array:
	var result := []
	for data in events:
		result.append([data.type, data.severity, data.closing_speed, data.normal])
	return result

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
