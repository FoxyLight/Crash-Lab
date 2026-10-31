extends SceneTree
## Optional real-mixer regression. Run graphically, without --fixed-fps.
## Headless dispatch tests cannot detect a silent spatial listener route.
var scene
var audio
var capture: AudioEffectCapture
var effect_index: int
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		push_error("Audio output checks require graphical Godot and a real audio driver")
		quit(1)
		return
	create_timer(30.0).timeout.connect(func(): push_error("Audio output checks timed out"); quit(1))
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	effect_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	await fresh()
	# Exercise real weapon event wiring at both authored starting positions.
	for actor in scene.players:
		await silence()
		actor.get_node("Blaster")._fire()
		await create_timer(0.6).timeout
		check_output("%s weapon event" % actor.name)
	# Cover every spatial gameplay waveform through the production voice pool.
	for cue in [&"crash_minor", &"crash_moderate", &"crash_major", &"repair", &"heavy_shot", &"impact", &"hit", &"damage", &"destroyed", &"respawn", &"wood_break", &"barrier_break", &"hazard_blast"]:
		await silence()
		audio.play_cue(cue, scene.listener.global_position)
		await create_timer(0.6).timeout
		check_output(str(cue))
	await silence()
	audio.set_muted(true)
	audio.play_cue(&"crash_major", scene.listener.global_position)
	await create_timer(0.6).timeout
	var muted := measure()
	check(muted.frames > 0 and muted.peak < 0.000001, "mute produces silent mixer frames")
	audio.set_muted(false)
	await silence()
	audio._on_match_finished(1)
	await create_timer(0.8).timeout
	check_output("winner event")
	await fresh()
	await silence()
	scene.players[1].get_node("Blaster")._fire()
	await create_timer(0.6).timeout
	check_output("spatial weapon after scene reload")
	AudioServer.remove_bus_effect(0, effect_index)
	scene.queue_free()
	await create_timer(0.25).timeout
	print("Audio output checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func fresh() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await create_timer(0.25).timeout
	scene = load("res://scenes/local_duel.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	audio = scene.get_node("CombatAudio")
	audio.set_muted(false)
	await create_timer(0.2).timeout

func silence() -> void:
	audio.stop_voices()
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	# Let the real audio thread release stopped streams before sampling silence.
	await create_timer(0.15).timeout
	capture.clear_buffer()

func measure() -> Dictionary:
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return {"frames": samples.size(), "peak": peak}

func check_output(label: String) -> void:
	var output := measure()
	print("MIX %s: %d frames, peak %.6f" % [label, output.frames, output.peak])
	check(output.frames > 0 and output.peak > 0.00001, "%s produces non-silent mixer output" % label)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
