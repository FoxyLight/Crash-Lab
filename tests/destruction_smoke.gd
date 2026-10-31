extends SceneTree
const Manager = preload("res://scripts/destruction/destruction_manager.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")
var scene
var manager
var car
var prop
var checks: int = 0
var failures: int = 0
var breaks: int = 0
var impacts: Array[Dictionary] = []

func _initialize() -> void:
	create_timer(180.0, true, true).timeout.connect(func(): push_error("Destruction checks timed out"); quit(1))
	run.call_deferred()

func run() -> void:
	await fixture("breakable_crate")
	check(prop.maximum_durability == 40 and prop.durability == 40 and prop.mass == 18, "crate starts intact as a lightweight physical obstacle")
	shot(20, Vector3(0, 1, 6), Vector3(0, 0, -110), car)
	await ticks(12)
	check(prop.durability == 20 and not prop.is_destroyed, "real blaster-speed sweep damages crate once")
	prop.durability_changed.connect(func(current, _maximum):
		if current <= 0:
			prop.take_damage(1000)
	)
	shot(80, Vector3(0, 1, 6), Vector3(0, 0, -65), car)
	await ticks(18)
	check(prop.is_destroyed and breaks == 1 and prop.last_source.get_ref() == car, "cannon destroys weakened crate with preserved shooter identity")
	check(prop.durability == 0 and breaks == 1, "reentrant durability observer cannot repeat the destruction transition")
	prop.take_damage(1000)
	check(breaks == 1, "destroyed prop ignores duplicate damage")
	check(prop.collision_layer == 0 and prop.collider.disabled, "destroyed crate removes solid and projectile collision")
	check(manager.pieces.size() == 8 and manager.pieces.all(func(piece): return not piece is CollisionObject3D), "breakup has eight non-solid pieces")
	await ticks(310)
	check(manager.pieces.is_empty(), "debris expires within 2.5 seconds without persistent bodies")
	await fixture("destructible_barrier")
	shot(20, Vector3(0, 1, 5), Vector3(0, 0, -20000), car)
	await ticks(3)
	check(prop.durability == 120, "extreme-speed projectile does not tunnel through intact thin cover")
	check(not ray(Vector3(0, 1, 5), Vector3(0, 1, -5)).is_empty(), "intact barrier blocks firing route")
	var behind = load("res://scenes/vehicles/rival_car.tscn").instantiate()
	behind.position = Vector3(0, 1.25, -8)
	scene.add_child(behind)
	disable(behind)
	behind.freeze = true
	shot(80, Vector3(0, 1, 5), Vector3(0, 0, -65), car)
	await ticks(18)
	check(prop.durability == 40 and behind.get_node("DamageReceiver").health == 120, "heavy cannon is stronger against cover with unchanged 80 damage and no penetration")
	shot(80, Vector3(0, 1, 5), Vector3(0, 0, -65), car)
	await ticks(18)
	check(prop.is_destroyed and ray(Vector3(0, 1, 5), Vector3(0, 1, -5)).is_empty(), "destroyed barrier opens a real physical route")
	shot(20, Vector3(0, 1, 5), Vector3(0, 0, -110), car)
	await ticks(25)
	check(behind.get_node("DamageReceiver").health == 100, "later shot passes through destroyed cover to opponent")
	car.linear_velocity = Vector3(0, 0, -25)
	await ticks(100)
	check(car.position.z < -1, "car drives through opened barrier without invisible collision")
	await fixture("destructible_barrier")
	await place(car, Vector3(0, 1.25, 3.0))
	car.linear_velocity = Vector3(0, 0, -2)
	var nearest_z: float = car.position.z
	for i in 600:
		await ticks(1)
		nearest_z = minf(nearest_z, car.position.z)
	check(prop.durability == 140 and not prop.is_destroyed, "gentle physical nudge cannot destroy sturdy cover")
	check(nearest_z > 2.3 and nearest_z < 3.0, "intact barrier physically stops the gentle approach")
	car.get_node("DriverInput").throttle = 1.0
	await ticks(240)
	check(prop.durability == 140, "sustained powered resting contact does not repeatedly damage cover")
	await fixture("breakable_crate")
	car.linear_velocity = Vector3(0, 0, -55)
	await ticks(65)
	print("Crate ram: z=", car.position.z, " speed=", car.linear_velocity.length(), " events=", impacts.size())
	check(prop.is_destroyed and breaks == 1, "actual 55 m/s ram destroys crate exactly once")
	check(car.position.z < -2 and car.linear_velocity.length() > 25, "high-speed smash retains forward momentum instead of stopping dead")
	check(car.global_basis.y.dot(Vector3.UP) > 0.8, "crate ram does not flip the chassis")
	check(not impacts.is_empty() and impacts[0].closing_speed > 35, "ram damage uses actual pre-solver normal contact data")
	check(car.get_node("DamageReceiver").health == 100, "ram adds no vehicle collision health damage")
	await fixture("destructible_barrier")
	car.position = Vector3(-5.01, 1.25, 4)
	car.linear_velocity = Vector3(0.5, 0, -30)
	await ticks(100)
	check(not prop.is_destroyed and prop.durability == 140, "fast tangential scrape with little normal closing speed does not ram-break cover")
	await fixture("destructible_barrier")
	car.linear_velocity = Vector3(0, 0, -12)
	await ticks(150)
	var first: float = prop.durability
	check(first > 0 and first < 140, "first moderate physical ram weakens barrier")
	prop.receive_vehicle_impact(impacts[0])
	check(prop.durability == first, "repeated delivery of an actual episode snapshot cannot double-apply ram damage")
	await place(car, Vector3(0, 1.25, 12))
	await ticks(60)
	car.linear_velocity = Vector3(0, 0, -12)
	await ticks(150)
	check(prop.durability < first, "separate impact after separation accumulates further damage")
	await fixture("destructible_barrier")
	car.linear_velocity = Vector3(0, 0, -55)
	await ticks(80)
	check(prop.is_destroyed and breaks == 1, "substantial high-speed ram destroys sturdy barrier without tunneling")
	await fixture("breakable_crate")
	for i in 12:
		var extra = load("res://scenes/props/breakable_crate.tscn").instantiate()
		extra.position = Vector3(20 + i * 3, 1, 10)
		manager.add_child(extra)
		extra.take_damage(1000)
	check(manager.pieces.size() == 64, "rapid destruction stress respects global 64-piece budget")
	await ticks(310)
	check(manager.pieces.is_empty(), "stress debris fully cleans up")
	await hazard_checks()
	await arena_checks()
	scene.queue_free()
	await ticks(3)
	print("Destruction smoke checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func hazard_checks() -> void:
	await fixture("energy_canister")
	await place(car, Vector3(5, 1.25, 0))
	prop.take_damage_from(30, car)
	check(prop.primed and prop.detonation_count == 0 and prop.warning != null, "hazard has visible radius and delayed fuse")
	await ticks(40)
	check(car.get_node("DamageReceiver").health == 100, "warning period precedes blast damage")
	await ticks(70)
	var near_health: float = car.get_node("DamageReceiver").health
	check(near_health > 55 and near_health < 100 and prop.detonation_count == 1, "one bounded radial explosion damages nearby car with falloff")
	await ticks(120)
	check(prop.detonation_count == 1 and car.get_node("DamageReceiver").health == near_health, "spent hazard never repeats damage")
	await fixture("energy_canister")
	await place(car, Vector3(9, 1.25, 0))
	prop.take_damage(30)
	await ticks(110)
	check(car.get_node("DamageReceiver").health > near_health and car.get_node("DamageReceiver").health < 100, "radial damage decreases with distance")
	await fixture("energy_canister")
	await place(car, Vector3(13, 1.25, 0))
	prop.take_damage(30)
	await ticks(110)
	check(car.get_node("DamageReceiver").health == 100, "outside blast radius receives no damage")
	await fixture("energy_canister")
	await place(car, Vector3(5, 1.25, 0))
	car.get_node("DamageReceiver").protection_remaining = 3.0
	prop.take_damage(30)
	await ticks(110)
	check(car.get_node("DamageReceiver").health == 100, "spawn protection rejects explosion damage")
	await fixture("energy_canister")
	await place(car, Vector3(5, 1.25, 0))
	block(Vector3(2.5, 1.5, 0), Vector3(1, 3, 8))
	prop.take_damage(30)
	await ticks(110)
	check(car.get_node("DamageReceiver").health == 100, "intact structural cover shields blast")
	await fixture("energy_canister")
	car.linear_velocity = Vector3(0, 0, -35)
	await ticks(160)
	check(prop.detonation_count == 1 and prop.last_source == null, "actual physical hazard ram detonates once without assigning a shooter")
	for source_kind in ["opponent", "self", "environment"]:
		await local_scene()
		var victim = scene.get_node("Player2")
		car = scene.get_node("Player1")
		prop = props_of_kind(2)[0]
		await place(car, Vector3(-18, 1.25, 0))
		await place(victim, Vector3(4, 1.25, 0))
		victim.get_node("DamageReceiver").take_damage_from(95, car)
		var source: Node = car if source_kind == "opponent" else (victim if source_kind == "self" else null)
		shot(80, Vector3(0, 1.1, 6), Vector3(0, 0, -110), source)
		await ticks(125)
		var match_node = scene.get_node("MatchController")
		check(victim.get_node("DamageReceiver").is_destroyed and match_node.player_score == (1 if source_kind == "opponent" else 0) and match_node.rival_score == 0, "%s hazard kill has fair lethal attribution" % source_kind)
		check(victim.get_node("DamageReceiver").get_death_source() == source, "%s blast retains only triggering projectile source" % source_kind)
		await ticks(380)
		check(not victim.get_node("DamageReceiver").is_destroyed and victim.get_node("DamageReceiver").get_death_source() == null and not victim.get_node("DamageReceiver").death_requires_source, "respawn clears hazard source and restores health/controls")
		check(prop.is_destroyed and prop.detonation_count == 1, "player respawn does not rebuild destroyed hazard")
	await local_scene()
	prop = props_of_kind(2)[0]
	prop.take_damage(100)
	scene.get_node("Player2/DamageReceiver").take_damage_from(1000, scene.get_node("Player1"))
	scene.get_node("MatchController").elimination_target = 1
	await ticks(120)
	check(scene.get_node("MatchController").state == 1 and prop.detonation_count == 0 and not prop.primed, "match completion cancels pending explosion")
	check(manager.pieces.is_empty() and manager.blast_effects.is_empty(), "finish clears all debris and explosion visuals")
	for i in 3:
		scene.get_node("MatchController").request_restart()
		await ticks(12)
		scene = current_scene
		manager = scene.get_node("Arena/Destruction")
		check(props_of_kind(2).size() == 1 and not props_of_kind(2)[0].is_destroyed and manager.enabled and manager.pieces.is_empty(), "restart restores one intact hazard and clean manager")
		check(props_of_kind(2)[0].sound_requested.get_connections().size() == 1, "reload has exactly one destruction audio connection")
		scene.get_node("MatchController").elimination_target = 1
		scene.get_node("Player2/DamageReceiver").take_damage_from(1000, scene.get_node("Player1"))
		await ticks(4)
	# Explicit null-source environmental damage must not use legacy AI fallback.
	await load_scene("duel")
	scene.get_node("Rival/DriverInput").set_physics_process(false)
	scene.get_node("Rival/DamageReceiver").take_damage_from(1000, null)
	await ticks(4)
	check(scene.get_node("MatchController").player_score == 0, "unattributed source-aware environmental death gives no AI-duel fallback point")

func arena_checks() -> void:
	for name in ["duel", "local_duel", "main"]:
		await load_scene(name)
		manager = scene.get_node("TestArena/Destruction" if name == "main" else "Arena/Destruction")
		check(props_of_kind(0).size() >= 2 and props_of_kind(1).size() >= 1 and props_of_kind(2).size() == 1, "%s loads crates, real cover and one hazard" % name)
		check(manager.vehicles().all(func(actor): return actor.is_spawn_clear()), "%s starts with clear vehicle spawns" % name)
		if name == "local_duel":
			prop = props_of_kind(1)[0]
			var cues: Array[StringName] = []
			scene.get_node("CombatAudio").set_muted(false)
			scene.get_node("CombatAudio").cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
			prop.take_damage(1000)
			await ticks(2)
			check(scene.views[0].world_3d == prop.get_world_3d() and scene.views[1].world_3d == prop.get_world_3d() and prop.is_destroyed, "both local cameras share exactly the same destroyed world object")
			check(cues.count(&"barrier_break") == 1, "one real shared-world destruction dispatches one spatial audio cue")
		if name == "duel":
			var rival = scene.get_node("Rival")
			var start: Vector3 = rival.position
			var shots: Array[int] = [0]
			rival.get_node("Blaster").shot_fired.connect(func(): shots[0] += 1)
			await ticks(3600)
			check(rival.position.distance_to(start) > 5 and rival.global_basis.y.dot(Vector3.UP) > 0.7, "AI drives and stays upright around new props")
			check(shots[0] > 0, "AI still finds firing opportunities around destruction layout")

func fixture(type: String) -> void:
	await clear()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	manager = Manager.new()
	scene.add_child(manager)
	prop = load("res://scenes/props/%s.tscn" % type).instantiate()
	prop.position = Vector3(0, 0.9 if type == "breakable_crate" else 1.2, 0)
	manager.add_child(prop)
	breaks = 0
	impacts.clear()
	prop.destroyed.connect(func(_p, _s): breaks += 1)
	car = load("res://scenes/vehicles/player_car.tscn").instantiate()
	car.position = Vector3(0, 1.25, 12)
	scene.add_child(car)
	disable(car)
	car.get_node("ImpactDetector").impact_detected.connect(func(data): impacts.append(data))
	await ticks(150)

func disable(actor: Node) -> void:
	actor.get_node("DriverInput").set_physics_process(false)
	actor.get_node("DriverInput").clear_commands()
	for weapon in actor.find_children("*", "", true, false):
		if weapon.has_method("_fire"):
			weapon.set_physics_process(false)

func props_of_kind(kind: int) -> Array:
	return manager.get_children().filter(func(node): return node.has_method("take_damage") and node.kind == kind)

func local_scene() -> void:
	await load_scene("local_duel")
	manager = scene.get_node("Arena/Destruction")
	disable(scene.get_node("Player1"))
	disable(scene.get_node("Player2"))

func load_scene(name: String) -> void:
	await clear()
	scene = load("res://scenes/%s.tscn" % name).instantiate()
	root.add_child(scene)
	current_scene = scene
	await ticks(4)

func clear() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await ticks(3)

func place(actor: RigidBody3D, location: Vector3) -> void:
	await physics_frame
	actor.freeze = true
	actor.global_transform = Transform3D(Basis.IDENTITY, location)
	actor.linear_velocity = Vector3.ZERO
	actor.angular_velocity = Vector3.ZERO
	await ticks(2)
	actor.freeze = false

func shot(damage: float, location: Vector3, velocity: Vector3, source: Node) -> void:
	var bullet := Projectile.new()
	bullet.damage = damage
	bullet.velocity = velocity
	bullet.damage_source = weakref(source) if source != null else null
	bullet.shooter_rid = source.get_rid() if source is CollisionObject3D else RID()
	scene.add_child(bullet)
	bullet.position = location

func ray(a: Vector3, b: Vector3) -> Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))

func block(location: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	scene.add_child(body)
	body.position = location

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)
