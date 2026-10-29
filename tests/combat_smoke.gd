extends SceneTree
var main
var car
var health
var turret
var shots: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	car = main.get_node("MuscleCar")
	health = car.get_node("DamageReceiver")
	turret = main.get_node("EnemyTurret")
	turret.weapon.shot_fired.connect(func(): shots += 1)
	await ticks(300)
	check(shots == 0 and health.health == 100.0, "starting runway is safe outside turret range")
	# Settle at a known combat approach facing the turret.
	await place(Vector3(40, 1.25, -78))
	check(turret.has_line_of_sight and not turret.fire_requested, "turret acquires visible player and warns before firing")
	await ticks(480)
	check(shots > 0 and shots <= 4 and health.health < 100.0, "slow turret projectiles damage player through collider receiver")
	var bar = main.get_node("CombatHUD").bar
	check(bar.value == health.health, "HUD health bar tracks damage")
	# Recovery button cannot be used to refill health.
	var before: float = health.health
	car.driver.reset_requested = true
	await ticks(2)
	check(health.health == before, "manual recovery does not heal combat damage")
	# Block the firing corridor and wait for existing shots to expire.
	var cover := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 5, 1)
	collision.shape = shape
	cover.add_child(collision)
	main.add_child(cover)
	cover.position = Vector3(40, 2.5, -88)
	await ticks(400)
	var shots_before := shots
	before = health.health
	await ticks(240)
	check(not turret.has_line_of_sight and shots == shots_before and health.health == before, "solid cover blocks target acquisition and shots")
	cover.queue_free()
	await ticks(2)
	# In-flight shots are cleared only for this isolated lifecycle assertion.
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	await ticks(2)
	health.take_damage(1000.0)
	shots_before = shots
	check(health.is_destroyed and health.health == 0.0 and not car.driver.controls_enabled, "lethal damage destroys vehicle and disables controls")
	Input.action_press("accelerate")
	Input.action_press("fire_weapon")
	Input.action_press("reset_vehicle")
	await ticks(60)
	check(car.driver.throttle == 0.0 and not car.driver.fire_requested and health.is_destroyed, "destroyed car cannot drive, fire, or skip respawn with reset")
	check(shots == shots_before and not turret.fire_requested, "turret stops targeting destroyed player")
	Input.action_release("accelerate")
	Input.action_release("fire_weapon")
	Input.action_release("reset_vehicle")
	# Restore the original safe spawn before automatic recovery executes.
	car.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(-25, 1.25, 25))
	await ticks(400)
	check(not health.is_destroyed and health.health == health.maximum_health and car.position.distance_to(Vector3(-25, 0.9, 25)) < 1.0 and car.linear_velocity.length() < 0.5, "automatic respawn restores health at safe spawn with cleared momentum")
	check(car.driver.controls_enabled and health.protection_remaining > 0.0, "respawn re-enables controls with temporary protection")
	health.take_damage(20.0)
	check(health.health == health.maximum_health, "spawn protection rejects incoming damage")
	await ticks(240)
	health.take_damage(20.0)
	check(health.health == 80.0 and health.hit_remaining > 0.0, "damage and hit feedback resume after protection expires")
	# Kill the turret using the actual forward player weapon.
	turret.target = null
	await place(Vector3(40, 1.25, -78))
	Input.action_press("fire_weapon")
	await ticks(150)
	Input.action_release("fire_weapon")
	check(turret.is_destroyed and turret.health == 0.0 and not turret.head.visible, "player blaster destroys turret and hides its gun")
	turret.target = car
	shots_before = shots
	await ticks(240)
	check(shots == shots_before and not turret.fire_requested, "destroyed turret cannot fire")
	await ticks(600)
	check(not turret.is_destroyed and turret.health == turret.maximum_health and turret.head.visible, "turret respawns with full health and visible gun")
	check(shots > shots_before, "respawned turret reacquires player and resumes combat")
	print("Combat smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func place(location: Vector3) -> void:
	car.spawn_transform = Transform3D(Basis.IDENTITY, location)
	car.driver.reset_requested = true
	await ticks(60)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
