extends SceneTree
## Run with --headless --fixed-fps 120 --script res://tests/weapon_smoke.gd
const Projectile = preload("res://scripts/weapons/projectile.gd")
var failures: int = 0
var shots: int = 0
var main
var target

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var car = main.get_node("MuscleCar")
	var weapon = car.get_node("Blaster")
	target = main.get_node("TestArena/TargetDummy")
	await ticks(240)
	weapon.shot_fired.connect(func(): shots += 1)
	Input.action_press("fire_weapon")
	Input.action_press("accelerate")
	await ticks(120)
	check(shots >= 6 and shots <= 8, "held fire respects seven shots per second while accelerating")
	check(car.signed_speed > 3.0, "weapon allows driving acceleration")
	Input.action_press("steer_right")
	Input.action_press("handbrake")
	var previous_shots := shots
	await ticks(60)
	check(shots > previous_shots and car.driver.handbrake and car.current_steering < 0.0, "firing continues with steering and handbrake")
	Input.action_release("fire_weapon")
	Input.action_release("accelerate")
	Input.action_release("steer_right")
	Input.action_release("handbrake")
	await ticks(5)
	previous_shots = shots
	await ticks(60)
	check(shots == previous_shots, "release stops firing")
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	await ticks(2)
	# A very fast segment crosses the whole thin target in one tick.
	var projectile = launch(Vector3(48, 1.5, 0), 20000.0)
	await ticks(3)
	check(target.health == 80.0 and not is_instance_valid(projectile), "fast projectile hits target, deals damage, and is removed")
	check(target.flash_remaining > 0.0, "damage triggers brief target flash")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.1)
	collider.shape = shape
	blocker.add_child(collider)
	main.add_child(blocker)
	blocker.position = Vector3(48, 1.5, -5)
	await ticks(2)
	projectile = launch(Vector3(48, 1.5, 0), 20000.0)
	await ticks(3)
	check(target.health == 80.0 and not is_instance_valid(projectile), "thin obstacle blocks fast shots before target")
	projectile = launch(Vector3(48, 1.5, -5), 20000.0)
	await ticks(3)
	check(target.health == 80.0 and not is_instance_valid(projectile), "shots starting inside an obstacle are blocked")
	# The same collider represents a shooter in the path, on the vehicle layer.
	blocker.collision_layer = 2
	await ticks(2)
	launch(Vector3(48, 1.5, 0), 20000.0, blocker.get_rid())
	await ticks(3)
	check(target.health == 60.0, "shooter RID excluded while target remains hittable")
	launch(Vector3(48, 1.5, 0), 20000.0)
	await ticks(3)
	check(target.health == 60.0, "vehicle layer blocks shots without shooter exclusion")
	blocker.queue_free()
	await ticks(2)
	projectile = launch(Vector3(60, 10, 10), 1.0)
	projectile.lifetime = 0.05
	await ticks(12)
	check(not is_instance_valid(projectile), "lifetime removes missed projectile")
	target.respawn_delay = 0.25
	for i in range(3):
		launch(Vector3(48, 1.5, 0), 20000.0)
		await ticks(3)
	check(target.is_destroyed and target.health == 0.0 and target.collider.disabled, "lethal hits destroy target and disable collision")
	target.take_damage(100.0)
	await ticks(40)
	check(not target.is_destroyed and target.health == target.maximum_health and not target.collider.disabled and target.visual.scale == Vector3.ONE, "respawn restores health, appearance, and solid collision")
	# Repeat the full lifecycle to catch stale destruction/cooldown state.
	for i in range(5):
		launch(Vector3(48, 1.5, 0), 20000.0)
		await ticks(3)
	check(target.is_destroyed, "respawned target can be destroyed again")
	await ticks(40)
	check(not target.is_destroyed and target.health == target.maximum_health, "second respawn restores health")
	# Actual mounted weapon must hit the range target from a settled chassis.
	car.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(48, 1.25, 15))
	car.driver.reset_requested = true
	await ticks(240)
	Input.action_press("fire_weapon")
	await ticks(105)
	Input.action_release("fire_weapon")
	check(target.is_destroyed, "front muzzle aims at target and destroys it through player input")
	await ticks(300)
	check(get_nodes_in_group("projectiles").is_empty(), "all projectiles clean up after release")
	Input.action_press("accelerate")
	await ticks(600)
	Input.action_release("accelerate")
	check(target.health == target.maximum_health and car.position.z > -12.0, "vehicle collides physically with target without dealing damage")
	print("Weapon smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func launch(location: Vector3, speed: float, excluded: RID = RID()):
	var projectile := Projectile.new()
	projectile.velocity = Vector3.FORWARD * speed
	projectile.shooter_rid = excluded
	main.add_child(projectile)
	projectile.global_position = location
	return projectile

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
