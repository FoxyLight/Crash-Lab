extends Node
## Scene-local collision observer. Audio observes the same event independently.
const Sparks = preload("res://scripts/effects/crash_sparks.gd")
@export_range(1, 16) var burst_limit: int = 8
var enabled: bool = true
var dispatch_count: int = 0

func _ready() -> void:
	for node in get_parent().find_children("ImpactDetector", "", true, false):
		node.impact_detected.connect(_on_impact)
	var match_node = get_parent().get_node_or_null("MatchController")
	if match_node != null:
		match_node.match_finished.connect(finish)
		if match_node.state == 1:
			finish()

func _on_impact(data: Dictionary) -> void:
	if not enabled:
		return
	dispatch_count += 1
	for camera in get_parent().find_children("*", "Camera3D", true, false):
		if camera.has_method("add_impact"):
			camera.add_impact(data)
	if DisplayServer.get_name() == "headless":
		return
	var count := 0
	for effect in get_tree().get_nodes_in_group("crash_effects"):
		if get_parent().is_ancestor_of(effect) and not effect.is_queued_for_deletion():
			count += 1
	if count >= burst_limit:
		return
	var burst := Sparks.new()
	burst.severity = data.severity
	burst.normal = data.normal
	get_parent().add_child(burst)
	burst.global_position = data.position + data.normal * 0.08

func finish(_result: int = 0) -> void:
	enabled = false
	for camera in get_parent().find_children("*", "Camera3D", true, false):
		if camera.has_method("clear_impact"):
			camera.clear_impact()
	for effect in get_tree().get_nodes_in_group("crash_effects"):
		if get_parent().is_ancestor_of(effect):
			effect.process_mode = Node.PROCESS_MODE_DISABLED
			effect.queue_free()
