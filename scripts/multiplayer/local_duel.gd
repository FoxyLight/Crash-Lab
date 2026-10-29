extends Node3D
## One physical world, two render views, one input router and one sound observer.
const Chase = preload("res://scripts/camera/chase_camera.gd")
const HUD = preload("res://scripts/multiplayer/local_player_hud.gd")
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var huds: Array[Control] = []
var containers: Array[SubViewportContainer] = []
var banner: Label
var result_panel: ColorRect
var result_label: Label
var listener: AudioListener3D
@onready var players: Array[RigidBody3D] = [$Player1, $Player2]

func _ready() -> void:
	var screen := CanvasLayer.new()
	add_child(screen)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(layout)
	for index in range(2):
		if index == 1:
			var divider := PanelContainer.new()
			divider.custom_minimum_size.y = 30
			layout.add_child(divider)
			banner = Label.new()
			banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			banner.add_theme_font_size_override("font_size", 15)
			divider.add_child(banner)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layout.add_child(container)
		containers.append(container)
		var view := SubViewport.new()
		view.size = Vector2i(1280, 345)
		view.world_3d = get_world_3d()
		view.own_world_3d = false
		view.audio_listener_enable_3d = false
		view.gui_disable_input = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(view)
		views.append(view)
		var camera := Camera3D.new()
		camera.set_script(Chase)
		camera.target = players[index]
		camera.far = 350.0
		view.add_child(camera)
		camera.current = true
		cameras.append(camera)
		var layer := CanvasLayer.new()
		view.add_child(layer)
		var hud := Control.new()
		hud.set_script(HUD)
		hud.vehicle = players[index]
		hud.match_controller = $MatchController
		hud.router = $InputRouter
		hud.player_index = index
		layer.add_child(hud)
		huds.append(hud)
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	$CombatAudio.status.hide()
	_build_result()
	$MatchController.match_finished.connect(_show_result)

func _build_result() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	result_panel = ColorRect.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.color = Color(0.025, 0.04, 0.06, 0.9)
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(result_panel)
	result_label = Label.new()
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 30)
	result_panel.add_child(result_label)
	result_panel.hide()

func _show_result(result: int) -> void:
	var title: String = {1: "PLAYER 1 WINS", 2: "PLAYER 2 WINS", 3: "DRAW"}.get(result, "MATCH FINISHED")
	result_label.text = "%s\n\nP1 %d — %d P2\n\nEnter / Controller Start — Play again\nRelease before pressing again" % [title, $MatchController.player_score, $MatchController.rival_score]
	result_panel.show()

func _process(_delta: float) -> void:
	var router = $InputRouter
	banner.text = "CRASH LAB v0.10  |  %s  |  F2: Change setup  |  M / D-pad down: Audio %s" % ["Two controllers" if router.two_gamepads else "Keyboard + controller", "OFF" if $CombatAudio.session_muted else "ON"]
	listener.global_position = (players[0].global_position + players[1].global_position) * 0.5 + Vector3.UP * 2.0
