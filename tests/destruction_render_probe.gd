extends SceneTree
## Optional Windows render/performance fixture; no headless or fixed-fps.
## Can run this script by absolute path against v0.10 for matched controls.
var scene
var failed: bool = false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("Render probe timeout"); quit(1))
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await load_arena("duel")
	await sample("AI intact", false)
	await sample("AI rapid destruction", true)
	await load_arena("local_duel")
	for actor in scene.players:
		actor.get_node("DriverInput").set_physics_process(false)
		actor.get_node("DriverInput").throttle = 0.65
		actor.get_node("DriverInput").fire_requested = true
		actor.linear_velocity = -actor.global_basis.z * 30
	await sample("split driving and firing", false)
	await sample("split 64-fragment stress", true)
	if "--capture" in OS.get_cmdline_user_args():
		await captures()
	scene.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)

func sample(title: String, destruction: bool) -> void:
	var manager = scene.get_node_or_null("Arena/Destruction")
	var times: Array[float] = []
	var peak_pieces: int = 0
	var peak_physics: float = 0
	await RenderingServer.frame_post_draw
	var previous := Time.get_ticks_usec()
	var start := previous
	if destruction and manager != null:
		for prop in manager.get_children():
			if prop.has_method("take_damage"):
				prop.take_damage(1000)
		for i in 8:
			manager.breakup(Vector3(i * 3 - 10, 1, 5), Vector3(2, 2, 2), Color("cfa65a"), 8)
	while Time.get_ticks_usec() - start < 3000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append((now - previous) / 1000.0)
		previous = now
		peak_physics = maxf(peak_physics, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		if manager != null:
			peak_pieces = maxi(peak_pieces, manager.pieces.size())
	var mean: float = 0
	for time in times:
		mean += time / times.size()
	times.sort()
	print("PERF ", title, " baseline=", manager == null, " n=", times.size(), " mean_ms=", mean, " p95_ms=", times[int(times.size() * 0.95)], " p99_ms=", times[int(times.size() * 0.99)], " max_physics_ms=", peak_physics, " peak_debris=", peak_pieces)

func load_arena(title: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await create_timer(0.3).timeout
	scene = load("res://scenes/%s.tscn" % title).instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(2.0).timeout

func captures() -> void:
	await load_arena("duel")
	disable(scene.get_node("Rival"))
	var player = scene.get_node("Player")
	disable(player)
	await place(player, Vector3(-42, 1.25, -8), 0)
	await create_timer(0.5).timeout
	await snap("destruction-intact")
	player.linear_velocity = Vector3(0, 0, -30)
	await create_timer(0.28).timeout
	player.get_node("DriverInput").brake = 1.0
	await snap("destruction-ram")
	print("CAPTURE ram speed=", player.linear_velocity.length(), " broken=", count_broken())
	await load_arena("duel")
	disable(scene.get_node("Rival"))
	player = scene.get_node("Player")
	disable(player)
	await place(player, Vector3(0, 1.25, 30), 0)
	await create_timer(0.5).timeout
	player.get_node("Loadout").select_weapon(1)
	player.get_node("HeavyCannon")._fire()
	await create_timer(1.3).timeout
	player.get_node("HeavyCannon")._fire()
	await create_timer(0.18).timeout
	await snap("destruction-weapon")
	print("CAPTURE weapon broken=", count_broken())
	await load_arena("duel")
	disable(scene.get_node("Rival"))
	player = scene.get_node("Player")
	disable(player)
	await place(player, Vector3(0, 1.25, 10), 0)
	await create_timer(0.5).timeout
	player.get_node("HeavyCannon").selected = false
	player.get_node("Blaster")._fire()
	await create_timer(0.18).timeout
	player.get_node("Blaster")._fire()
	await create_timer(0.35).timeout
	await snap("destruction-hazard-warning")
	await create_timer(0.7).timeout
	await snap("destruction-hazard")
	print("CAPTURE hazard health=", player.get_node("DamageReceiver").health)
	await load_arena("local_duel")
	for actor in scene.players:
		disable(actor)
	await place(scene.players[0], Vector3(0, 1.25, 31), 0)
	await place(scene.players[1], Vector3(0, 1.25, 7), PI)
	await create_timer(0.8).timeout
	player = scene.players[0]
	player.get_node("Loadout").select_weapon(1)
	player.get_node("HeavyCannon")._fire()
	await create_timer(1.3).timeout
	player.get_node("HeavyCannon")._fire()
	await create_timer(0.2).timeout
	await snap("destruction-shared")
	print("CAPTURE shared broken=", count_broken(), " debris=", scene.get_node("Arena/Destruction").pieces.size())
	# A real blast near both humans: bounded damage, one world and effect.
	var hazard = scene.get_node("Arena/Destruction").get_children().filter(func(n): return n.has_method("take_damage") and n.kind == 2)[0]
	await place(scene.players[0], Vector3(-4, 1.25, 0), 0)
	await place(scene.players[1], Vector3(4, 1.25, 0), PI)
	hazard.take_damage_from(30, scene.players[0])
	await sample("blast near both humans", false)
	print("BLAST both health=", scene.players[0].get_node("DamageReceiver").health, "/", scene.players[1].get_node("DamageReceiver").health, " count=", hazard.detonation_count)
	for i in 3:
		scene.get_node("MatchController").elimination_target = 1
		scene.players[1].get_node("DamageReceiver").take_damage_from(1000, scene.players[0])
		await create_timer(0.1).timeout
		scene.get_node("MatchController").request_restart()
		await create_timer(0.5).timeout
		scene = current_scene
	print("RESTARTS views=", scene.views.size(), " props=", scene.get_node("Arena/Destruction").get_child_count(), " debris=", scene.get_node("Arena/Destruction").pieces.size())

func disable(actor: Node) -> void:
	actor.get_node("DriverInput").set_physics_process(false)
	actor.get_node("DriverInput").clear_commands()

func place(actor: RigidBody3D, location: Vector3, yaw: float) -> void:
	var generation: int = actor.reset_generation
	actor.spawn_transform = Transform3D(Basis(Vector3.UP, yaw), location)
	actor.driver.reset_requested = true
	await create_timer(0.2).timeout
	if actor.reset_generation == generation:
		failed = true
		push_error("Render fixture could not safely place %s at %s" % [actor.name, location])

func count_broken() -> int:
	return scene.get_node("Arena/Destruction").get_children().filter(func(n): return n.has_method("take_damage") and n.is_destroyed).size()

func snap(title: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/images/%s.png" % title)
	failed = failed or error != OK
	print("SNAP ", title, " error=", error)
