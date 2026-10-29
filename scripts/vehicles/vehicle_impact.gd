extends Node
## GodotPhysics3D contact snapshots are world-space and contain pre-solver velocities.
## Either contact reporter feeds the same pair owner; severity may escalate per episode.
signal impact_detected(data: Dictionary)
enum Severity { NONE, MINOR, MODERATE, MAJOR }
@export_group("Closing speed (m/s)")
@export var minimum_speed: float = 1.5
@export var moderate_speed: float = 5.0
@export var major_speed: float = 12.0
@export_group("Contact episodes")
@export var separation_delay: float = 0.35
@export var event_interval: float = 0.12
@export var debug_output: bool = false
@export_group("Optional exaggeration — off pending playtest")
@export var exaggeration_enabled: bool = false
@export_range(0.0, 0.2) var impulse_scale: float = 0.04
@export var maximum_linear_impulse: float = 700.0 # N s; 0.5 m/s at default mass
@export var maximum_angular_impulse: float = 180.0 # kg m²/s; yaw only
var contacts: Dictionary = {}
var pending: Array[Dictionary] = []
var pending_reactions: Array[Dictionary] = []
var last_impact: Dictionary = {}
var event_count: int = 0
var clock: float = 0.0
var grace_remaining: float = 0.0
var last_linear_impulse := Vector3.ZERO
var last_angular_impulse := Vector3.ZERO
@onready var vehicle: RigidBody3D = get_parent()

func _ready() -> void:
	add_to_group("vehicle_impacts")
	var health = vehicle.get_node("DamageReceiver")
	health.destroyed.connect(reset_tracking)
	health.respawned.connect(reset_tracking)

func active() -> bool:
	return vehicle.combat_active and not vehicle.get_node("DamageReceiver").is_destroyed

func classify(closing: float) -> Severity:
	if not is_finite(closing) or closing < maxf(0.0, minimum_speed):
		return Severity.NONE
	if closing >= maxf(moderate_speed, major_speed):
		return Severity.MAJOR
	return Severity.MODERATE if closing >= maxf(minimum_speed, moderate_speed) else Severity.MINOR

func reset_tracking() -> void:
	contacts.clear()
	pending.clear()
	pending_reactions.clear()
	last_impact.clear()
	last_linear_impulse = Vector3.ZERO
	last_angular_impulse = Vector3.ZERO
	grace_remaining = separation_delay
	# A reset of either participant invalidates the shared owner's episode too.
	for detector in get_tree().get_nodes_in_group("vehicle_impacts"):
		if detector != self:
			detector.forget_vehicle(vehicle)

func forget_vehicle(actor: Node) -> void:
	contacts.erase(actor.get_instance_id())
	for queue in [pending, pending_reactions]:
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].get("collider") == actor:
				queue.remove_at(i)

func sample(state: PhysicsDirectBodyState3D) -> void:
	clock = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	grace_remaining = maxf(0.0, grace_remaining - state.step)
	if not active():
		return
	var reactions := pending_reactions.duplicate()
	pending_reactions.clear()
	for data in reactions:
		if exaggeration_enabled and grace_remaining <= 0.0 and is_instance_valid(data.collider) and (data.type != "vehicle" or data.collider.get_node("ImpactDetector").active()):
			_apply_exaggeration(state, data)
	var strongest: Dictionary = {}
	for i in state.get_contact_count():
		var other = state.get_contact_collider_object(i)
		if not is_instance_valid(other):
			continue
		var normal := state.get_contact_local_normal(i).normalized()
		# Suspension rays never report body contacts. Also reject floor/ramp support.
		if not normal.is_finite() or normal.length_squared() < 0.9 or absf(normal.y) > 0.65:
			continue
		var relative := state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		var position := state.get_contact_local_position(i)
		if not relative.is_finite() or not position.is_finite():
			continue
		var closing := maxf(0.0, -relative.dot(normal))
		var id: int = other.get_instance_id()
		if strongest.has(id) and strongest[id].closing_speed >= closing:
			continue
		strongest[id] = {"vehicle": vehicle, "collider": other, "position": position,
			"collider_position": state.get_contact_collider_position(i),
			"normal": normal, "relative_velocity": relative, "closing_speed": closing,
			"severity": classify(closing), "type": "vehicle" if other.has_node("ImpactDetector") else "arena",
			"tick": Engine.get_physics_frames()}
	for id in strongest:
		var data: Dictionary = strongest[id]
		if grace_remaining > 0.0:
			continue
		var other = data.collider
		if data.type == "vehicle" and vehicle.get_instance_id() > other.get_instance_id():
			other.get_node("ImpactDetector").observe_contact(mirrored(data))
		else:
			observe_contact(data)
	# Drop departed objects; no retained Node references in episode history.
	for id in contacts.keys():
		if clock - contacts[id].last_seen > separation_delay:
			contacts.erase(id)

func mirrored(data: Dictionary) -> Dictionary:
	var result := data.duplicate()
	result.vehicle = data.collider
	result.collider = data.vehicle
	result.position = data.get("collider_position", data.position)
	result.collider_position = data.position
	result.normal = -data.normal
	result.relative_velocity = -data.relative_velocity
	return result

func observe_contact(data: Dictionary) -> void:
	if not active() or grace_remaining > 0.0 or not is_instance_valid(data.collider):
		return
	if data.type == "vehicle" and not data.collider.get_node("ImpactDetector").active():
		return
	clock = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	var id: int = data.collider.get_instance_id()
	if not contacts.has(id) or clock - contacts[id].last_seen > separation_delay:
		contacts[id] = {"last_seen": clock, "peak": 0, "emitted_at": -INF}
	var episode: Dictionary = contacts[id]
	episode.last_seen = clock
	data.severity = classify(data.closing_speed)
	if data.severity <= episode.peak:
		# Both reporters can describe the same category. Retain the stronger
		# snapshot while it is queued without dispatching another event.
		for i in pending.size():
			if pending[i].collider == data.collider and data.closing_speed > pending[i].closing_speed:
				data.ready_at = pending[i].ready_at
				pending[i] = data
		return
	# A low/no-energy touch must not consume a later significant crash. Upgrade
	# only on a higher category (at most three events), never repeat a held major.
	episode.peak = data.severity
	data.ready_at = maxf(clock, episode.emitted_at + event_interval)
	for i in pending.size():
		if pending[i].collider == data.collider:
			pending[i] = data
			return
	if pending.size() < 8:
		pending.append(data)

func _apply_exaggeration(state: PhysicsDirectBodyState3D, data: Dictionary) -> void:
	# Planar central push and separately capped yaw avoid lift and pitch/roll torque.
	var direction: Vector3 = data.normal.slide(Vector3.UP).normalized()
	var magnitude := clampf(vehicle.mass * data.closing_speed * impulse_scale, 0.0, maxf(0.0, maximum_linear_impulse))
	last_linear_impulse = direction * magnitude
	var lever: Vector3 = data.position - state.transform.origin - state.center_of_mass
	var yaw := clampf(lever.cross(last_linear_impulse).y, -maxf(0.0, maximum_angular_impulse), maxf(0.0, maximum_angular_impulse))
	last_angular_impulse = Vector3.UP * yaw
	state.apply_central_impulse(last_linear_impulse)
	state.apply_torque_impulse(last_angular_impulse)

func _physics_process(_delta: float) -> void:
	# Dispatch outside force integration: observers may safely create scene effects.
	var batch := pending.duplicate()
	pending.clear()
	for data in batch:
		if not active() or not is_instance_valid(data.collider):
			continue
		if data.type == "vehicle" and not data.collider.get_node("ImpactDetector").active():
			continue
		var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
		if now < data.ready_at:
			pending.append(data)
			continue
		var id: int = data.collider.get_instance_id()
		if contacts.has(id):
			contacts[id].emitted_at = now
		if data.severity == Severity.MAJOR:
			if exaggeration_enabled and pending_reactions.size() < 8:
				pending_reactions.append(data)
			if data.type == "vehicle":
				var detector = data.collider.get_node("ImpactDetector")
				if detector.exaggeration_enabled and detector.pending_reactions.size() < 8:
					detector.pending_reactions.append(mirrored(data))
		last_impact = data
		event_count += 1
		if debug_output:
			print("CRASH ", {"actor": str(vehicle.get_path()), "other": str(data.collider.get_path()), "m_s": data.closing_speed, "severity": data.severity, "position": data.position, "normal": data.normal, "relative": data.relative_velocity})
		impact_detected.emit(data)
