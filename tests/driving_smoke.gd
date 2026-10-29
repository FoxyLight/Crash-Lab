extends SceneTree
## Deterministic physics checks. Run with --headless --fixed-fps 120 --script res://tests/driving_smoke.gd
var car
var failures: int = 0

func _initialize() -> void:
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
	print("Driving smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

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
