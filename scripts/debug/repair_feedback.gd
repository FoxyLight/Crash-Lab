extends CanvasLayer
@export var player: RigidBody3D
var player_message: Label
var world_message: Label3D
var player_remaining: float = 0.0
var world_remaining: float = 0.0
var world_actor: WeakRef
var enabled: bool = true

func _ready() -> void:
	player_message = Label.new()
	player_message.position = Vector2(20, 550)
	player_message.add_theme_font_size_override("font_size", 22)
	player_message.add_theme_color_override("font_color", Color("75ffac"))
	player_message.add_theme_color_override("font_shadow_color", Color.BLACK)
	player_message.add_theme_constant_override("shadow_offset_x", 2)
	player_message.add_theme_constant_override("shadow_offset_y", 2)
	add_child(player_message)
	world_message = Label3D.new()
	world_message.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world_message.font_size = 56
	world_message.pixel_size = 0.012
	world_message.modulate = Color("75ffac")
	get_parent().add_child.call_deferred(world_message)
	for node in get_parent().find_children("*", "", true, false):
		if node.has_signal("collected") and node.has_method("try_collect"):
			node.collected.connect(_on_collected)
	var match_node = get_parent().get_node_or_null("MatchController")
	if match_node != null:
		match_node.match_finished.connect(_on_match_finished)
	player_message.hide()
	world_message.hide()

func _on_collected(actor: RigidBody3D, amount: float) -> void:
	if not enabled:
		return
	var amount_text := str(int(amount)) if amount == floorf(amount) else str(amount)
	var message := "REPAIRED +%s HP" % amount_text
	if actor == player:
		player_message.text = message
		player_remaining = 1.5
		player_message.show()
	else:
		world_message.text = message
		world_actor = weakref(actor)
		world_remaining = 1.5
		world_message.show()

func _process(delta: float) -> void:
	player_remaining = maxf(0.0, player_remaining - delta)
	world_remaining = maxf(0.0, world_remaining - delta)
	player_message.visible = enabled and player_remaining > 0.0
	world_message.visible = enabled and world_remaining > 0.0
	if world_actor != null and is_instance_valid(world_actor.get_ref()):
		world_message.global_position = world_actor.get_ref().global_position + Vector3.UP * 4.0

func _on_match_finished(_result: int) -> void:
	enabled = false
	player_remaining = 0.0
	world_remaining = 0.0
	player_message.hide()
	world_message.hide()
