extends SceneTree
const Bank = preload("res://scripts/audio/sound_bank.gd")
const Audio = preload("res://scripts/audio/combat_audio.gd")
var main
var audio
var player
var rival
var cues: Array[StringName] = []
var failures: int = 0

func _initialize() -> void:
	create_timer(60.0, true, true).timeout.connect(func(): push_error("Audio checks timeout"); quit(1))
	run.call_deferred()

func run() -> void:
	var valid := true
	for name in Bank.RECIPES:
		var stream = Bank.get_stream(name)
		var peak: float = 0.0
		var energy: float = 0.0
		for i in range(0, stream.data.size(), 2):
			var sample: float = stream.data.decode_s16(i) / 32768.0
			peak = maxf(peak, absf(sample))
			energy += sample * sample
		valid = valid and stream.mix_rate == 22050 and not stream.stereo and stream.data.size() > 1000 and peak > 0.05 and peak <= 0.601 and energy > 0.1 and abs(stream.data.decode_s16(0)) < 10 and abs(stream.data.decode_s16(stream.data.size() - 2)) < 10
	check(valid, "all ten cues contain bounded non-silent PCM with quiet endpoints")
	check(Bank.get_stream(&"player_shot").data != Bank.get_stream(&"enemy_shot").data and Bank.get_stream(&"victory").data != Bank.get_stream(&"defeat").data and Bank.get_stream(&"draw").data != Bank.get_stream(&"victory").data, "player/enemy shots and three results have distinct waveforms")
	var original: PackedByteArray = Bank.get_stream(&"impact").data.duplicate()
	Bank.cache.erase(&"impact")
	seed(8123)
	var expected := randf()
	seed(8123)
	check(Bank.get_stream(&"impact").data == original and randf() == expected, "sound synthesis is deterministic and leaves gameplay RNG untouched")
	check(Bank.get_stream(&"hit") == Bank.get_stream(&"hit"), "sound resources are cached rather than rebuilt per event")
	Audio.session_muted = false
	main = load("res://scenes/duel.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	bind_scene()
	rival.driver.set_physics_process(false)
	rival.driver.clear_commands()
	audio.cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
	await ticks(180)
	check(cues.is_empty(), "initial health and spawn setup do not play false damage/respawn cues")
	check(audio.world_voices.size() == 12 and audio.ui_voices.size() == 3 and audio.volume_db <= -12.0, "scene creates bounded world/UI voice pools with conservative gain")
	player.get_node("Blaster")._fire()
	rival.get_node("Blaster")._fire()
	check(count(&"player_shot") == 1 and count(&"enemy_shot") == 1, "actual weapon shots trigger the correct cue once")
	check(DisplayServer.get_name() == "headless" or audio.world_voices[0].playing, "graphical runs start real spatial playback")
	check(audio.world_voices[0].global_position.distance_to(player.get_node("Blaster/Muzzle").global_position) < 0.001, "shot sound is placed at the world-space muzzle")
	clear_projectiles()
	await ticks(2)
	var before := count(&"player_shot")
	Input.action_press("fire_weapon")
	await ticks(120)
	Input.action_release("fire_weapon")
	check(count(&"player_shot") - before >= 6 and count(&"player_shot") - before <= 8, "held-fire audio follows the existing weapon cooldown")
	clear_projectiles()
	await ticks(2)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	main.add_child(wall)
	wall.global_position = player.get_node("Blaster/Muzzle").global_position - player.global_basis.z * 4.0
	await ticks(2)
	before = count(&"impact")
	player.get_node("Blaster")._fire()
	await ticks(12)
	check(count(&"impact") == before + 1, "real projectile collision relays a world impact cue")
	wall.queue_free()
	await ticks(8)
	before = count(&"impact")
	for i in range(100):
		player.get_node("Blaster").projectile_impacted.emit(Vector3.ZERO)
	check(count(&"impact") == before + 1 and audio.world_voices.size() == 12, "impact bursts are rate-limited without creating more players")
	await ticks(8)
	before = count(&"impact")
	player.get_node("Blaster").projectile_lifetime = 0.01
	player.get_node("Blaster")._fire()
	await ticks(4)
	player.get_node("Blaster").projectile_lifetime = 2.0
	check(count(&"impact") == before, "projectile expiry does not falsely report an impact")
	var health = rival.get_node("DamageReceiver")
	before = count(&"hit")
	health.take_damage(20.0)
	check(count(&"hit") == before + 1, "accepted opponent damage produces a hit cue")
	health.protection_remaining = 1.0
	health.take_damage(20.0)
	check(count(&"hit") == before + 1 and health.health == 100.0, "protected damage produces no false hit confirmation")
	health.protection_remaining = 0.0
	before = count(&"damage")
	player.get_node("DamageReceiver").take_damage(10.0)
	check(count(&"damage") == before + 1 and audio.ui_voices[0].stream == Bank.get_stream(&"damage"), "player damage uses centered UI feedback")
	health.respawn_delay = 0.1
	health.spawn_protection = 0.0
	before = count(&"destroyed")
	health.take_damage(10000.0)
	await ticks(30)
	check(count(&"destroyed") == before + 1 and count(&"respawn") == 1 and not health.is_destroyed, "destruction and non-final respawn play once each")
	check(count(&"hit") == 2, "restoring health does not produce a hit cue")
	main.get_node("MatchController").elimination_target = 2
	health.take_damage(10000.0)
	await ticks(4)
	check(count(&"victory") == 1 and not audio.combat_enabled and audio.world_voices.all(func(voice): return not voice.playing), "match completion silences combat voices and plays one centered result")
	before = cues.size()
	audio.play_cue(&"impact")
	audio._on_shot(player.get_node("Blaster"))
	await ticks(120)
	check(cues.size() == before, "finished matches reject late combat cues")
	key_mute(true)
	await ticks(2)
	check(Audio.session_muted and audio.status.text.contains("OFF") and audio.ui_voices.all(func(voice): return not voice.playing), "M mutes immediately and updates the visible status after a result")
	audio.play_cue(&"victory", Vector3.ZERO, false, false)
	check(cues.size() == before, "mute suppresses both combat and result playback")
	await ticks(3)
	check(Audio.session_muted, "holding mute does not toggle repeatedly")
	key_mute(false)
	await ticks(2)
	pad_mute(true)
	await ticks(2)
	check(not Audio.session_muted and audio.status.text.contains("ON"), "controller D-pad down toggles audio without changing gameplay controls")
	pad_mute(false)
	audio.set_muted(true)
	var old_id: int = main.get_instance_id()
	main.get_node("MatchController").request_restart()
	for i in range(30):
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
			break
	bind_scene()
	check(main.get_instance_id() != old_id and Audio.session_muted and audio.status.text.contains("OFF") and audio.world_voices.size() == 12, "restart preserves session mute while rebuilding a clean bounded pool")
	check(player.get_node("Blaster").shot_fired.get_connections().size() == 1 and audio.combat_enabled, "restart reconnects each weapon observer once and restores combat audio")
	# Check other result variants and training without changing their gameplay.
	for cue in [&"defeat", &"draw"]:
		audio.set_muted(false)
		var local_cues: Array[StringName] = []
		audio.cue_played.connect(func(name, _spatial, _location): local_cues.append(name), CONNECT_ONE_SHOT)
		audio._on_match_finished(2 if cue == &"defeat" else 3)
		check(local_cues == [cue], "%s result selects its own centered cue" % cue)
	main.queue_free()
	await ticks(2)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	audio = main.get_node("CombatAudio")
	cues.clear()
	audio.cue_played.connect(func(cue, _spatial, _location): cues.append(cue))
	var dummy = main.get_node("TestArena/TargetDummy")
	dummy.respawn_delay = 0.1
	dummy.take_damage(10000.0)
	await ticks(30)
	check(count(&"hit") == 1 and count(&"destroyed") == 1 and count(&"respawn") == 1 and audio.combat_enabled, "training target damage and repeated practice lifecycle receive audio")
	Audio.session_muted = false
	print("Audio smoke checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func bind_scene() -> void:
	main = current_scene
	audio = main.get_node("CombatAudio")
	player = main.get_node("Player")
	rival = main.get_node("Rival")

func clear_projectiles() -> void:
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()

func count(cue: StringName) -> int:
	return cues.count(cue)

func key_mute(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	event.pressed = pressed
	Input.parse_input_event(event)

func pad_mute(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_DOWN
	event.pressed = pressed
	Input.parse_input_event(event)

func ticks(amount: int) -> void:
	for i in amount:
		await physics_frame
	await process_frame

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		failures += 1
