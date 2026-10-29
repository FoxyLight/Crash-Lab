extends SceneTree
## Deterministic physics checks. Run with --headless --fixed-fps 120 --script res://tests/driving_smoke.gd
var car
var failures: int = 0

func _initialize() -> void:
	create_timer(120.0, true, true).timeout.connect(func(): push_error("Driving checks timed out"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	car = main.get_node("MuscleCar")
	await ticks(240)
	check(car.grounded_wheels == 4 and car.linear_velocity.length() < 0.5, "settles on four wheels")
	Input.action_press("accelerate")
	await ticks(360)
	var accelerated: float = car.signed_speed
	print("Acceleration speed m/s: ", accelerated)
	check(accelerated > 15.0 and accelerated <= car.maximum_speed + 1.0, "forward acceleration")
	check(accelerated > 21.0 and accelerated > 18.46 * 1.15, "three-second acceleration improves over previous measured 18.46 m/s baseline")
	Input.action_release("accelerate")
	Input.action_press("brake_reverse")
	await ticks(120)
	check(absf(car.signed_speed) < accelerated * 0.6, "service brake reduces speed")
	await ticks(300)
	check(car.signed_speed < -3.0, "brake transitions to reverse")
	Input.action_release("brake_reverse")
	await recover(Vector3(-25, 1.25, 25))
	Input.action_press("accelerate")
	await ticks(180)
	Input.action_press("steer_right", 0.6)
	await ticks(90)
	print("Steering displacement x: ", car.position.x + 25.0)
	check(car.position.x > -24.0 and car.global_basis.y.dot(Vector3.UP) > 0.8, "right steering turns right and stays upright")
	Input.action_press("handbrake")
	await ticks(60)
	check(car.driver.handbrake and car.linear_velocity.is_finite(), "handbrake remains stable while turning")
	Input.action_release("handbrake")
	Input.action_release("steer_right")
	Input.action_release("accelerate")
	await recover(Vector3(-25, 1.25, 25))
	check(car.position.distance_to(Vector3(-25, 0.87, 25)) < 1.0 and car.linear_velocity.length() < 0.5, "reset restores spawn and clears momentum")
	# Drive directly into the north barrier. CCD should keep the car inside.
	await recover(Vector3(-25, 1.25, -105))
	Input.action_press("accelerate")
	await ticks(360)
	check(car.position.z > -125.0 and car.linear_velocity.length() < 3.0, "solid barrier stops chassis")
	Input.action_release("accelerate")
	await recover(Vector3(0, 1.25, -38))
	Input.action_press("accelerate", 0.55)
	var peak_height: float = 0.0
	for i in range(720):
		await ticks(1)
		peak_height = maxf(peak_height, car.position.y)
	Input.action_release("accelerate")
	print("Ramp peak height: ", peak_height, " position: ", car.position)
	check(peak_height > 2.0 and car.position.z < -83 and car.global_basis.y.dot(Vector3.UP) > 0.65 and car.grounded_wheels == 4, "crosses ramps and lands upright")
	await recover(Vector3(-25, 1.25, 25))
	car.global_position.y = -20.0 # Test setup: force the fall condition.
	await ticks(240)
	check(car.position.y > 0.0, "fall recovery")
	await speed_run(main)
	print("Driving smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func speed_run(main: Node) -> void:
	# A long straight test-only floor measures power/damping equilibrium without
	# arena walls cutting the run short; the real controller still drives on rays.
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 4000)
	shape.shape = box
	floor_body.add_child(shape)
	main.add_child(floor_body)
	floor_body.position = Vector3(500, -0.5, -1800)
	var new_force: float = car.engine_force
	var new_cutoff: float = car.maximum_speed
	car.engine_force = 15000.0
	car.maximum_speed = 42.0
	await recover(Vector3(500, 1.25, 0))
	Input.action_press("accelerate")
	await ticks(360)
	var old3: float = car.signed_speed
	await ticks(360)
	var old6: float = car.signed_speed
	await ticks(2880)
	var old_terminal: float = car.signed_speed
	print("Previous powertrain: 3s=", old3, " 6s=", old6, " 30s=", old_terminal, " requested/applied N=", car.drive_force_requested, "/", car.drive_force_applied, " damping=", car.effective_linear_damping)
	Input.action_release("accelerate")
	car.engine_force = new_force
	car.maximum_speed = new_cutoff
	await recover(Vector3(500, 1.25, 0))
	var camera = main.get_node("ChaseCamera")
	check(absf(camera.fov - 75.0) < 0.1, "camera returns to configured 75-degree resting FOV")
	Input.action_press("accelerate")
	await ticks(120)
	print("Speed after 1 s: ", car.signed_speed, " FOV: ", camera.fov)
	check(camera.fov > camera.base_fov and camera.fov < 85.0, "speed FOV interpolates gradually as the physical car accelerates")
	await ticks(600)
	var speed6: float = car.signed_speed
	print("Speed after 6 s: ", speed6, " FOV: ", camera.fov)
	check(speed6 > old6 * 1.15 and car.global_basis.y.y > 0.8 and car.grounded_wheels == 4, "six-second run gains over 15 percent speed with stable four-wheel suspension")
	await ticks(2880)
	print("New powertrain: 6s=", speed6, " 30s=", car.signed_speed, " FOV=", camera.fov, " requested/applied N=", car.drive_force_requested, "/", car.drive_force_applied, " damping=", car.effective_linear_damping)
	check(car.signed_speed > old_terminal * 1.20 and car.signed_speed < car.maximum_speed and car.linear_velocity.is_finite(), "sustained throttle gains over 20 percent terminal speed without bypassing physics")
	check(absf(car.drive_force_requested - car.drive_force_applied) < 100.0, "straight-line near-terminal speed is not being silently clipped by the tire-force bound")
	check(camera.fov > 83.0 and camera.fov <= 85.01, "high-speed FOV stays within modest configured 75-to-85-degree range")
	Input.action_release("accelerate")
	Input.action_press("brake_reverse")
	await ticks(240)
	check(car.signed_speed < 10.0 and car.global_basis.y.y > 0.8, "approved service brake stops higher-speed motion while upright")
	Input.action_release("brake_reverse")
	await recover(Vector3(500, 1.25, 0))
	check(absf(camera.fov - camera.base_fov) < 0.1, "speed FOV settles back after recovery without altering chase orientation")

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func recover(location: Vector3) -> void:
	car.spawn_transform = Transform3D(Basis.IDENTITY, location)
	car.reset_height = location.y
	car.driver.reset_requested = true
	await ticks(240)

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
