extends Node
## Destruction events are grouped by physics tick; only completed ticks are resolved.
signal score_changed(player_score: int, rival_score: int)
signal match_finished(result: Result)
enum State { PLAYING, FINISHED }
enum Result { NONE, VICTORY, DEFEAT, DRAW }
@export_range(1, 20) var elimination_target: int = 3
@export var player: RigidBody3D
@export var rival: RigidBody3D
@export var require_damage_source: bool = false # Strict for local play; legacy one-arg AI fixtures remain compatible.
@export var input_router: Node
var state: State = State.PLAYING
var result: Result = Result.NONE
var player_score: int = 0
var rival_score: int = 0
var pending_eliminations: Dictionary = {}
var credited: Array[bool] = [false, false]
var restart_armed: bool = false
var restart_requested: bool = false

func _ready() -> void:
	process_physics_priority = 1000
	for index in range(2):
		var participant = player if index == 0 else rival
		participant.get_node("DamageReceiver").destroyed.connect(_on_destroyed.bind(index))
		participant.get_node("DamageReceiver").respawned.connect(_on_respawned.bind(index))

func _on_destroyed(index: int) -> void:
	if state != State.PLAYING or credited[index]:
		return
	credited[index] = true
	var victim = player if index == 0 else rival
	var opponent = rival if index == 0 else player
	var source: Node = victim.get_node("DamageReceiver").get_death_source()
	if (require_damage_source or source != null or victim.get_node("DamageReceiver").death_requires_source) and source != opponent:
		return
	var tick := Engine.get_physics_frames()
	var points: Vector2i = pending_eliminations.get(tick, Vector2i.ZERO)
	if index == 0:
		points.y += 1
	else:
		points.x += 1
	pending_eliminations[tick] = points

func _on_respawned(index: int) -> void:
	if state == State.PLAYING:
		credited[index] = false

func _physics_process(_delta: float) -> void:
	if state != State.PLAYING:
		return
	var ticks := pending_eliminations.keys()
	ticks.sort()
	for tick in ticks:
		if tick >= Engine.get_physics_frames():
			continue
		var points: Vector2i = pending_eliminations[tick]
		pending_eliminations.erase(tick)
		player_score += points.x
		rival_score += points.y
		score_changed.emit(player_score, rival_score)
		if player_score >= elimination_target or rival_score >= elimination_target:
			_finish()
			return

func _finish() -> void:
	state = State.FINISHED
	if player_score >= elimination_target and rival_score >= elimination_target:
		result = Result.DRAW
	else:
		result = Result.VICTORY if player_score >= elimination_target else Result.DEFEAT
	pending_eliminations.clear()
	player.finish_combat()
	rival.finish_combat()
	for group in ["projectiles", "combat_effects"]:
		for node in get_tree().get_nodes_in_group(group):
			if get_parent().is_ancestor_of(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				node.queue_free()
	match_finished.emit(result)

func _process(_delta: float) -> void:
	if input_router != null:
		var restart: bool = input_router.consume_restart()
		if state == State.FINISHED and restart:
			request_restart()
		return
	if not Input.is_action_pressed("restart_match"):
		restart_armed = true
	if state == State.FINISHED and restart_armed and Input.is_action_just_pressed("restart_match"):
		request_restart()

func request_restart() -> void:
	if state != State.FINISHED or restart_requested:
		return
	restart_requested = true
	_reload.call_deferred()

func _reload() -> void:
	var error := get_tree().reload_current_scene()
	if error != OK:
		restart_requested = false
		push_error("Could not restart duel: %s" % error_string(error))
