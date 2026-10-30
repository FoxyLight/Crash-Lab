extends Node3D
## Scene-local signal observer. Audio never drives gameplay or consumes game RNG.
signal cue_played(cue: StringName, spatial: bool, location: Vector3)
const Bank = preload("res://scripts/audio/sound_bank.gd")
static var session_muted: bool = false
static var mute_armed: bool = true
@export var player: RigidBody3D
@export var input_router: Node
@export var shared_mix: bool = false
@export_range(-40.0, 0.0) var volume_db: float = -16.0
@export_range(1, 24) var world_voice_limit: int = 12
@export_range(1, 6) var ui_voice_limit: int = 3
var world_voices: Array[AudioStreamPlayer3D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var world_index: int = 0
var ui_index: int = 0
var combat_enabled: bool = true
var impact_cooldown: float = 0.0
var previous_health: Dictionary = {}
var status: Label

func _ready() -> void:
	for cue in Bank.RECIPES:
		Bank.get_stream(cue)
	for i in world_voice_limit:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = 12.0
		voice.max_distance = 100.0
		voice.volume_db = volume_db
		voice.max_db = volume_db
		add_child(voice)
		world_voices.append(voice)
	for i in ui_voice_limit:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = volume_db
		add_child(voice)
		ui_voices.append(voice)
	for node in get_parent().find_children("*", "", true, false):
		if node.has_signal("impact_detected"):
			node.impact_detected.connect(_on_crash)
		if node.has_signal("collected") and node.has_method("try_collect"):
			node.collected.connect(_on_repair_collected)
		if node.has_signal("shot_fired") and node.has_signal("projectile_impacted"):
			node.shot_fired.connect(_on_shot.bind(node))
			node.projectile_impacted.connect(_on_impact)
		if node.has_signal("health_changed") and node.has_signal("destroyed"):
			var actor: Node3D = node.get_parent() if node.name == "DamageReceiver" else node
			previous_health[node.get_instance_id()] = node.health
			node.health_changed.connect(_on_health_changed.bind(node, actor))
			node.destroyed.connect(_on_destroyed.bind(actor))
			node.respawned.connect(_on_respawned.bind(actor))
	var match_node = get_parent().get_node_or_null("MatchController")
	if match_node != null:
		match_node.match_finished.connect(_on_match_finished)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	status = Label.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	status.offset_left = -340
	status.offset_top = -35
	status.offset_right = -20
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(status)
	_update_status()

func _physics_process(delta: float) -> void:
	impact_cooldown = maxf(0.0, impact_cooldown - delta)

func _exit_tree() -> void:
	stop_voices()
	for voice in world_voices:
		voice.stream = null
	for voice in ui_voices:
		voice.stream = null

func _process(_delta: float) -> void:
	if input_router != null:
		if input_router.consume_mute():
			set_muted(not session_muted)
		return
	if not Input.is_action_pressed("mute_audio"):
		mute_armed = true
	elif Input.is_action_just_pressed("mute_audio") and mute_armed:
		mute_armed = false
		set_muted(not session_muted)

func set_muted(muted: bool) -> void:
	session_muted = muted
	if muted:
		stop_voices()
	_update_status()

func _update_status() -> void:
	status.text = "M / D-pad down — Audio %s" % ("OFF" if session_muted else "ON")

func stop_voices() -> void:
	for voice in world_voices:
		voice.stop()
	for voice in ui_voices:
		voice.stop()

func play_cue(cue: StringName, location: Vector3 = Vector3.ZERO, spatial: bool = true, is_combat: bool = true) -> void:
	if session_muted or (is_combat and not combat_enabled):
		return
	var stream := Bank.get_stream(cue)
	if stream == null:
		return
	if spatial:
		var voice := world_voices[world_index]
		world_index = (world_index + 1) % world_voices.size()
		voice.stop()
		voice.global_position = location
		voice.stream = stream
		# Fast headless checks validate dispatch/PCM without opening a dummy mixer.
		if DisplayServer.get_name() != "headless":
			voice.play()
	else:
		var voice := ui_voices[ui_index]
		ui_index = (ui_index + 1) % ui_voices.size()
		voice.stop()
		voice.stream = stream
		if DisplayServer.get_name() != "headless":
			voice.play()
	cue_played.emit(cue, spatial, location)

func _on_shot(weapon: Node3D) -> void:
	var cue: StringName = weapon.shot_cue
	if cue == &"":
		cue = &"player_shot" if shared_mix or weapon.shooter == player else &"enemy_shot"
	play_cue(cue, weapon.muzzle.global_position)

func _on_repair_collected(actor: RigidBody3D, _amount: float) -> void:
	play_cue(&"repair", actor.global_position, shared_mix or actor != player)

func _on_impact(location: Vector3) -> void:
	if impact_cooldown <= 0.0:
		play_cue(&"impact", location)
		impact_cooldown = 0.04

func _on_crash(data: Dictionary) -> void:
	var cue: StringName = {1: &"crash_minor", 2: &"crash_moderate", 3: &"crash_major"}.get(data.severity, &"crash_minor")
	play_cue(cue, data.position)

func _on_health_changed(health: float, _maximum: float, receiver: Node, actor: Node3D) -> void:
	var id := receiver.get_instance_id()
	if health < previous_health.get(id, health):
		play_cue(&"damage" if shared_mix or actor == player else &"hit", actor.global_position, shared_mix or actor != player)
	previous_health[id] = health

func _on_destroyed(actor: Node3D) -> void:
	play_cue(&"destroyed", actor.global_position)

func _on_respawned(actor: Node3D) -> void:
	play_cue(&"respawn", actor.global_position, shared_mix or actor != player)

func _on_match_finished(result: int) -> void:
	combat_enabled = false
	stop_voices()
	var cue: StringName = {1: &"victory", 2: &"defeat", 3: &"draw"}.get(result, &"draw")
	if shared_mix and result in [1, 2]:
		cue = &"victory"
	play_cue(cue, Vector3.ZERO, false, false)
