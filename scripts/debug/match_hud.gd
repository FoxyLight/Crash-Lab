extends CanvasLayer
@export var match_controller: Node
@export var player_hud: CanvasLayer
@export var rival_hud: CanvasLayer
var scoreboard: Label
var result_panel: Control
var result_label: Label

func _ready() -> void:
	layer = 20
	scoreboard = Label.new()
	scoreboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	scoreboard.offset_left = -150
	scoreboard.offset_right = 150
	scoreboard.offset_top = 20
	scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard.add_theme_font_size_override("font_size", 22)
	scoreboard.add_theme_color_override("font_shadow_color", Color.BLACK)
	scoreboard.add_theme_constant_override("shadow_offset_x", 2)
	scoreboard.add_theme_constant_override("shadow_offset_y", 2)
	add_child(scoreboard)
	result_panel = ColorRect.new()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.color = Color(0.025, 0.04, 0.06, 0.85)
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_panel)
	result_label = Label.new()
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.offset_left = -350
	result_label.offset_top = -120
	result_label.offset_right = 350
	result_label.offset_bottom = 120
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 32)
	result_panel.add_child(result_label)
	result_panel.hide()
	match_controller.score_changed.connect(_update_score)
	match_controller.match_finished.connect(_show_result)
	_update_score(0, 0)

func _update_score(player_score: int, rival_score: int) -> void:
	scoreboard.text = "YOU %d — %d RIVAL\nFirst to %d eliminations" % [player_score, rival_score, match_controller.elimination_target]

func _show_result(result: int) -> void:
	var title: String = {1: "VICTORY", 2: "DEFEAT", 3: "DRAW"}.get(result, "MATCH FINISHED")
	result_label.text = "%s\n\nYOU %d — %d RIVAL\n\nEnter / Controller Start — Play again" % [title, match_controller.player_score, match_controller.rival_score]
	result_panel.show()
	scoreboard.hide()
	player_hud.hide()
	rival_hud.hide()
