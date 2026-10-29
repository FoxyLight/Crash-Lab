extends SceneTree
const Projectile = preload("res://scripts/weapons/projectile.gd")
var main
var car
var rival
var ai
var health
var failures: int = 0
var shots: int = 0

func _initialize() -> void:
	create_timer(120.0, true, true).timeout.connect(func(): push_error("Rival checks exceeded 120 simulated seconds"); quit(1))
	_run.call_deferred()

func _run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/duel.tscn", "duel is configured launch scene")
	main = load("res://scenes/duel.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	car = main.get_node("Player")
	rival = main.get_node("Rival")
	ai = rival.get_node("DriverInput")
	health = rival.get_node("DamageReceiver")
	rival.get_node("Blaster").shot_fired.connect(func(): shots += 1)
	check(main.find_children("*", "RigidBody3D", true, false).size() == 2 and main.get_node_or_null("EnemyTurret") == null, "duel contains two vehicles and no turret")
	ai.target = null
	var start: Vector3 = rival.position
	var start_basis: Basis = rival.global_basis
	var peak_turn: float = 0.0
	for i in range(600):
		await ticks(1)
		peak_turn = maxf(peak_turn, rival.global_basis.z.distance_to(start_basis.z))
	print("Patrol travel: ", rival.position.distance_to(start), " speed: ", rival.linear_velocity.length(), " resets: ", ai.reset_count)
	check(rival.position.distance_to(start) > 12.0 and peak_turn > 0.05, "AI commands physically move and turn rival without player input")
	check(ai.state == "PATROL" and ai.reset_count == 0, "moving patrol does not repeatedly reset")
	# Controlled firing fixture: aligned vehicles away from cover.
	ai.set_physics_process(false)
	ai.clear_commands()
	await place(rival, Vector3(50, 1.25, 5), 0.0)
	await place(car, Vector3(50, 1.25, -20), 0.0)
	rival.freeze = true
	car.freeze = true
	ai.target = car
	ai._physics_process(1.0 / 120.0)
	print("Firing fixture: rival=", rival.position, " player=", car.position, " state=", ai.state, " fire=", ai.fire_requested, " LOS=", ai.has_line_of_sight)
	check(ai.state == "PURSUIT" and ai.fire_requested and ai.has_line_of_sight, "visible aligned player is pursued and fired upon")
	await ticks(180)
	check(car.get_node("DamageReceiver").health < 100.0 and health.health == health.maximum_health, "enemy projectiles damage player and exclude shooter")
	# Start an actual weapon shot inside its own damage area: both RIDs must be excluded.
	var muzzle = rival.get_node("Blaster/Muzzle")
	var original_muzzle: Vector3 = muzzle.position
	muzzle.position.z = 1.0
	rival.get_node("Blaster")._fire()
	await ticks(10)
	muzzle.position = original_muzzle
	check(health.health == health.maximum_health, "mounted weapon excludes its own chassis and roof hurtbox")
	ai.target = null
	ai._physics_process(1.0 / 120.0)
	clear_projectiles()
	await ticks(2)
	# Shooting the rival with a swept player projectile exercises the shared receiver.
	var bullet := Projectile.new()
	bullet.velocity = Vector3.BACK * 20000.0
	bullet.shooter_rid = car.get_rid()
	main.add_child(bullet)
	bullet.global_position = Vector3(50, 1.1, -17)
	await ticks(3)
	check(health.health == health.maximum_health - 20.0, "player projectile damages rival through shared health receiver")
	# Aim/range/visibility gates are command checks with fixed transforms.
	car.global_position = Vector3(65, 1.0, -15)
	await ticks(2)
	ai.target = car
	ai._physics_process(1.0 / 120.0)
	check(not ai.fire_requested, "off-axis player cannot be fired upon")
	car.global_position = Vector3(50, 1.0, -45)
	await ticks(2)
	ai._physics_process(1.0 / 120.0)
	check(ai.state == "PURSUIT" and not ai.fire_requested, "pursuit beyond firing range does not shoot")
	car.global_position = Vector3(50, 1.0, -70)
	await ticks(2)
	ai._physics_process(1.0 / 120.0)
	check(ai.state == "PATROL" and not ai.fire_requested, "out-of-engagement player returns rival to patrol")
	car.global_position = Vector3(50, 1.0, -20)
	await ticks(2)
	var cover := block(Vector3(50, 1.5, -8), Vector3(8, 3, 1))
	await ticks(2)
	ai._physics_process(1.0 / 120.0)
	check(ai.state == "PATROL" and not ai.fire_requested and not ai.has_line_of_sight, "cover prevents pursuit acquisition and firing")
	var hp_before: float = health.health
	bullet = Projectile.new()
	bullet.velocity = Vector3.BACK * 20000.0
	bullet.shooter_rid = car.get_rid()
	main.add_child(bullet)
	bullet.global_position = Vector3(50, 1, -17)
	await ticks(3)
	check(health.health == hp_before, "cover physically blocks projectile damage")
	cover.queue_free()
	await ticks(2)
	var player_health = car.get_node("DamageReceiver")
	player_health.protection_remaining = 2.0
	ai._physics_process(1.0 / 120.0)
	check(ai.state == "PATROL" and not ai.fire_requested, "protected player is not pursued or shot")
	player_health.protection_remaining = 0.0
	player_health.take_damage(1000.0)
	ai._physics_process(1.0 / 120.0)
	check(ai.state == "PATROL" and not ai.fire_requested, "destroyed player is not pursued or shot")
	# Block both original spawns with solid parked vehicles, then free them.
	car.freeze = false
	rival.freeze = false
	ai.target = null
	ai.clear_commands()
	car.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(-50, 1.25, -40))
	var player_blocker := block(Vector3(-50, 1.25, -40), Vector3(2, 1, 4), 2)
	await ticks(480)
	check(player_health.is_destroyed and player_health.waiting_for_spawn and not car.driver.controls_enabled, "occupied player spawn defers healing and controls")
	player_blocker.queue_free()
	await ticks(240)
	check(not player_health.is_destroyed and player_health.health == 100.0 and car.position.distance_to(Vector3(-50, 0.9, -40)) < 1.0, "player safely respawns once occupied spawn clears")
	rival.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(50, 1.25, 40))
	health.respawn_delay = 0.2
	var rival_blocker := block(Vector3(50, 1.25, 40), Vector3(2, 1, 4), 2)
	ai.stuck_time = 10.0
	ai.recovery_attempts = 2
	health.take_damage(1000.0)
	await ticks(90)
	check(health.is_destroyed and health.waiting_for_spawn and ai.throttle == 0.0 and not ai.fire_requested, "destroyed rival cannot drive or fire while spawn is occupied")
	rival_blocker.queue_free()
	await ticks(240)
	check(not health.is_destroyed and health.health == health.maximum_health and ai.controls_enabled and ai.stuck_time == 0.0 and ai.recovery_attempts == 0, "rival respawn restores health, commands, and clean AI state")
	# Freeze movement only in the fixture to simulate an inescapable obstruction.
	rival.freeze = true
	ai.target = null
	ai.set_physics_process(true)
	ai.patrol_points = PackedVector3Array([Vector3(50, 0, 0)])
	await ticks(200)
	check(ai.reverse_remaining == 0.0 and ai.reset_count == 0, "stuck recovery waits for configured delay")
	await ticks(100)
	check(ai.state == "RECOVERING" and ai.brake > 0.0, "sustained lack of progress triggers reverse recovery")
	await ticks(1500)
	check(ai.reset_count > 0, "repeated failed reverse recovery uses delayed safe reset")
	ai.set_physics_process(false)
	ai.clear_commands()
	ai.reset_requested = false
	ai.reverse_remaining = 0.0
	rival.rotation.x = PI
	await ticks(2)
	ai._physics_process(ai.rollover_delay + 0.1)
	check(ai.reset_requested and ai.throttle == 0.0 and not ai.fire_requested, "sustained rollover requests safe last-resort reset")
	ai.reset_requested = false
	rival.freeze = false
	# Direct physical collision, with both weapons disabled.
	await place(car, Vector3(55, 1.25, 30), 0.0)
	await place(rival, Vector3(55, 1.25, 17), 0.0)
	player_health.protection_remaining = 0.0
	health.protection_remaining = 0.0
	var player_hp: float = player_health.health
	var rival_hp: float = health.health
	Input.action_press("accelerate")
	await ticks(300)
	Input.action_release("accelerate")
	print("Collision fixture positions: player=", car.position, " rival=", rival.position)
	check(rival.position.z < 15.0 and car.position.z > rival.position.z + 3.0, "vehicle-to-vehicle collision transfers momentum and prevents pass-through")
	check(player_health.health == player_hp and health.health == rival_hp, "physical vehicle collision does not remove health")
	# Repeat the full duel lifecycle using the player's actual mounted blaster.
	ai.clear_commands()
	await place(car, Vector3(50, 1.25, 25), 0.0)
	await place(rival, Vector3(50, 1.25, 0), PI)
	health.respawn_delay = 4.0
	Input.action_press("fire_weapon")
	await ticks(165)
	Input.action_release("fire_weapon")
	check(health.is_destroyed and not ai.controls_enabled and not ai.fire_requested, "player mounted blaster destroys rival and stops its commands")
	var previous_shots := shots
	ai.target = car
	ai.set_physics_process(true)
	await ticks(1200)
	check(not health.is_destroyed and shots > previous_shots, "rival respawns and resumes live combat after being defeated")
	var training = load("res://scenes/main.tscn").instantiate()
	root.add_child(training)
	check(training.get_node_or_null("EnemyTurret") != null and training.get_node_or_null("TestArena/TargetDummy") != null, "original training scene still loads its turret and target")
	training.queue_free()
	print("Rival smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func place(body, location: Vector3, yaw: float) -> void:
	body.spawn_transform = Transform3D(Basis(Vector3.UP, yaw), location)
	body.driver.reset_requested = true
	await ticks(180)

func block(location: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	main.add_child(body)
	body.position = location
	return body

func clear_projectiles() -> void:
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
