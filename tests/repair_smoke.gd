extends SceneTree
const Pickup = preload("res://scenes/pickups/repair_pickup.tscn")
const Bank = preload("res://scripts/audio/sound_bank.gd")
var main
var player
var rival
var hp
var rhp
var pad
var collections: Array = []
var cues: Array = []
var damage_signals: int = 0
var health_signals: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(90.0, true, true).timeout.connect(func(): push_error("Repair checks timeout"); quit(1))
	run.call_deferred()

func run() -> void:
	check(Bank.get_stream(&"repair").data != Bank.get_stream(&"respawn").data and Bank.get_stream(&"repair").data != Bank.get_stream(&"damage").data, "repair cue has its own waveform rather than replaying respawn or damage")
	main = load("res://scenes/duel.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	bind_scene()
	rival.driver.set_physics_process(false)
	rival.driver.clear_commands()
	await ticks(180)
	check(main.get_node("RepairPickups").get_child_count() == 3, "duel contains three fixed non-spawn repair placements")
	hp.damaged.connect(func(): damage_signals += 1)
	hp.health_changed.connect(func(_health, _max): health_signals += 1)
	hp.take_damage(40.0)
	var damage_before := damage_signals
	var health_before := health_signals
	check(hp.restore_health(25.0) == 25.0 and hp.health == 85.0, "health API restores and returns actual positive repair")
	check(hp.restore_health(25.0) == 15.0 and hp.health == 100.0, "health API clamps partial repair to existing maximum")
	check(hp.restore_health(25.0) == 0.0 and hp.restore_health(0.0) == 0.0 and hp.restore_health(-10.0) == 0.0 and hp.restore_health(INF) == 0.0 and hp.restore_health(NAN) == 0.0, "full health, non-positive and non-finite repair requests do nothing")
	check(damage_signals == damage_before and health_signals == health_before + 2 and main.get_node("MatchController").player_score == 0 and main.get_node("MatchController").rival_score == 0, "repair emits health updates without damage or score side effects")
	hp.take_damage(0.5)
	check(hp.restore_health(25.0) == 0.5 and hp.health == 100.0, "fractional missing health returns an accurate partial repair")
	player.get_node("Loadout").select_weapon(1)
	player.get_node("HeavyCannon").cooldown = 1.0
	hp.take_damage(20.0)
	hp.protection_remaining = 1.0
	var generation: int = player.reset_generation
	check(hp.restore_health(10.0) == 10.0 and hp.protection_remaining == 1.0 and player.get_node("Loadout").selected_index == 1 and player.get_node("HeavyCannon").cooldown == 1.0 and player.reset_generation == generation, "repair preserves shield duration, selected weapon, cooldown and reset state")
	hp.protection_remaining = 0.0
	hp.restore_health(100.0)
	rhp.take_damage(15.0)
	check(rhp.restore_health(25.0) == 15.0 and rhp.health == 120.0, "rival restores against its own 120 HP maximum")
	player.freeze = true
	rival.freeze = true
	player.global_position = Vector3(55, 1.25, 50)
	rival.global_position = Vector3(65, 1.25, 50)
	main.get_node("CombatAudio").cue_played.connect(func(cue, spatial, _at): cues.append([cue, spatial]))
	# Move an existing production pad to exercise its real feedback/audio wiring.
	pad = main.get_node("RepairPickups/WestRepair")
	pad.global_position = Vector3(55, 0, 50)
	pad.collected.connect(func(actor, amount): collections.append([actor, amount]))
	await ticks(5)
	check(pad.available and pad.remaining == 0.0 and collections.is_empty(), "full-health physical overlap leaves pickup and timer untouched")
	hp.take_damage(30.0)
	var reentrant_results: Array[bool] = []
	hp.health_changed.connect(func(_health, _max): reentrant_results.append(pad.try_collect()), CONNECT_ONE_SHOT)
	var cue_before: int = cue_count(&"repair")
	var hit_before: int = cue_count(&"damage")
	await ticks(3)
	check(hp.health == 95.0 and not pad.available and collections.size() == 1 and collections[0][1] == 25.0, "damaged vehicle already inside pad collects once on the next physics step")
	check(reentrant_results == [false], "pickup is already unavailable during receiver callbacks")
	check(cue_count(&"repair") == cue_before + 1 and cues.back() == [&"repair", false] and cue_count(&"damage") == hit_before, "player repair uses one centered cue without a damage cue")
	check(main.get_node("RepairFeedback").player_message.text == "REPAIRED +25 HP" and main.get_node("CombatHUD").bar.value == 95.0, "repair HUD reports actual amount and existing health bar updates")
	var remaining: float = pad.remaining
	await ticks(30)
	check(hp.health == 95.0 and collections.size() == 1 and pad.remaining < remaining and pad.remaining > 11.0 and not pad.marker.visible and pad.label.text.contains("Returns"), "unavailable pickup counts down without repeated repairs or duplicate hurtbox triggers")
	# Accelerated return for bounded repeated-cycle testing; production default stays 12s.
	pad.respawn_delay = 0.2
	pad.remaining = 0.05
	await ticks(10)
	check(hp.health == 100.0 and collections.size() == 2 and collections.back()[1] == 5.0 and main.get_node("RepairFeedback").player_message.text == "REPAIRED +5 HP", "camping damaged body may collect on return with partial repair feedback")
	await ticks(40)
	check(pad.available and pad.marker.visible and pad.label.text.contains("+25"), "pickup returns visibly after delay and stays available for full-health body")
	# Two symmetric bodies overlap; rigid contacts are frozen to keep the tie exact.
	player.global_position = Vector3(53, 1.25, 50)
	rival.global_position = Vector3(57, 1.25, 50)
	await ticks(4)
	pad.set_physics_process(false)
	hp.take_damage(30.0)
	rhp.take_damage(30.0)
	var before: int = collections.size()
	pad.set_physics_process(true)
	await ticks(3)
	check(collections.size() == before + 1 and collections.back()[0] == player and hp.health == 95.0 and rhp.health == 90.0, "equal-distance collectors use lexical scene paths and award only Player once")
	# Ignore the full-health nearer body and award the eligible rival.
	pad.set_physics_process(false)
	hp.restore_health(100.0)
	player.global_position = Vector3(55, 1.25, 50)
	rival.global_position = Vector3(57, 1.25, 50)
	pad.available = true
	pad.remaining = 0.0
	await ticks(4)
	pad.set_physics_process(true)
	await ticks(3)
	check(rhp.health == 115.0 and collections.back()[0] == rival and cues.back() == [&"repair", true], "full-health nearer player does not block rival collection and world audio")
	check(main.get_node("RepairFeedback").world_message.visible and main.get_node("RepairFeedback").world_message.text == "REPAIRED +25 HP", "rival receives a separate world repair message")
	# Distance precedes names when both bodies can benefit.
	pad.set_physics_process(false)
	player.global_position = Vector3(52.5, 1.25, 50)
	rival.global_position = Vector3(56, 1.25, 50)
	hp.take_damage(30.0)
	rhp.take_damage(30.0)
	pad.available = true
	await ticks(4)
	pad.set_physics_process(true)
	await ticks(3)
	check(collections.back()[0] == rival, "nearest eligible body wins before lexical tie-break")
	# Real overlap by a static body and a vehicle-layer area is not a collector.
	player.global_position = Vector3(40, 1.25, 50)
	rival.global_position = Vector3(70, 1.25, 50)
	var fake := StaticBody3D.new()
	fake.collision_layer = 2
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collider.shape = shape
	fake.add_child(collider)
	main.add_child(fake)
	fake.position = Vector3(55, 1, 50)
	var fake_area := Area3D.new()
	fake_area.collision_layer = 2
	var area_shape := CollisionShape3D.new()
	area_shape.shape = shape
	fake_area.add_child(area_shape)
	main.add_child(fake_area)
	fake_area.position = fake.position
	pad.available = true
	before = collections.size()
	await ticks(6)
	check(pad.available and collections.size() == before, "static obstacles and damage-area-like overlaps cannot consume pickups")
	fake.queue_free()
	fake_area.queue_free()
	# A real moving chassis crosses the non-solid pad and receives healing.
	player.freeze = false
	player.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(55, 1.25, 60))
	player.driver.reset_requested = true
	await ticks(180)
	hp.restore_health(100.0)
	hp.take_damage(40.0)
	pad.available = true
	pad.respawn_delay = 12.0
	before = collections.size()
	Input.action_press("accelerate")
	await ticks(240)
	Input.action_release("accelerate")
	check(collections.size() == before + 1 and hp.health == 85.0 and player.position.z < 49.0, "actual driving collects repair and passes through without a solid collision")
	# Healing a dead vehicle cannot revive it; pad cannot consume for that body.
	player.freeze = true
	player.position = Vector3(55, 1.25, 50)
	hp.respawn_delay = 5.0
	hp.take_damage(10000.0)
	pad.available = true
	before = collections.size()
	await ticks(5)
	check(hp.restore_health(25.0) == 0.0 and hp.is_destroyed and hp.health == 0.0 and pad.available and collections.size() == before, "dead bodies cannot consume repair or be revived")
	# Rival collection while muted must still heal, without a cue.
	main.get_node("CombatAudio").set_muted(true)
	rival.position = Vector3(55, 1.25, 50)
	var rival_before: float = rhp.health
	var sounds: int = cues.size()
	await ticks(5)
	check(rhp.health > rival_before and cues.size() == sounds, "mute suppresses repair sound without suppressing collection")
	main.get_node("CombatAudio").set_muted(false)
	var match_node = main.get_node("MatchController")
	match_node.elimination_target = 1
	rhp.take_damage(10000.0)
	await ticks(4)
	var stopped: float = pad.remaining
	before = collections.size()
	pad.try_collect()
	main.get_node("RepairFeedback")._on_collected(rival, 25.0)
	await ticks(180)
	check(not pad.enabled and pad.remaining == stopped and stopped == 0.0 and not pad.try_collect() and collections.size() == before, "finished match cancels timers and rejects queued collection attempts")
	check(hp.restore_health(25.0) == 0.0 and rhp.restore_health(25.0) == 0.0 and not main.get_node("RepairFeedback").player_message.visible and not main.get_node("RepairFeedback").world_message.visible, "result blocks healing and clears temporary repair feedback")
	var late = Pickup.instantiate()
	main.add_child(late)
	late.global_position = rival.global_position
	await ticks(3)
	check(not late.enabled and not late.try_collect(), "pickup added after an existing result immediately adopts the finished lifecycle")
	late.queue_free()
	# Repeated scene reload creates available pickups and one observer of each kind.
	var clean := true
	for cycle in range(2):
		var old_id: int = main.get_instance_id()
		main.get_node("MatchController").request_restart()
		for i in range(30):
			await process_frame
			if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
				break
		bind_scene()
		for pickup in main.get_node("RepairPickups").get_children():
			clean = clean and pickup.available and pickup.enabled and pickup.remaining == 0.0 and pickup.collected.get_connections().size() == 2
		if cycle == 0:
			main.get_node("MatchController").elimination_target = 1
			rhp.take_damage(10000.0)
			await ticks(4)
	check(clean, "repeated match restart restores all pickups with exactly one audio and feedback observer")
	main.queue_free()
	await ticks(2)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("MuscleCar")
	player.freeze = true
	player.position = Vector3(-48, 1.25, 28)
	hp = player.get_node("DamageReceiver")
	pad = main.get_node("RepairPickups/DemoRepair")
	pad.respawn_delay = 0.1
	hp.take_damage(60.0)
	await ticks(50)
	check(hp.health == 100.0 and pad.enabled and main.get_node_or_null("MatchController") == null, "training continuously returns its demo pickup through multiple repairs")
	print("Repair smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func bind_scene() -> void:
	main = current_scene
	player = main.get_node("Player")
	rival = main.get_node("Rival")
	hp = player.get_node("DamageReceiver")
	rhp = rival.get_node("DamageReceiver")

func cue_count(cue: StringName) -> int:
	return cues.filter(func(item): return item[0] == cue).size()

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
