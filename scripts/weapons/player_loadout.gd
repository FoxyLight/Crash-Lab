extends Node
## Selection is temporary; firing_enabled remains the permanent match-end gate.
signal selection_changed(index: int)
@onready var vehicle: RigidBody3D = get_parent()
@onready var driver = vehicle.get_node("DriverInput")
@onready var health = vehicle.get_node("DamageReceiver")
@onready var weapons: Array[Node3D] = [$"../Blaster", $"../HeavyCannon"]
var selected_index: int = 0
var active: bool = true
var last_shot_tick: int = -1

func _ready() -> void:
	process_physics_priority = -5
	for weapon in weapons:
		weapon.loadout = self
	driver.weapon_cycle_armed = not Input.is_action_pressed("cycle_weapon")
	health.respawned.connect(_on_respawned)
	_apply_selection(0)

func _physics_process(_delta: float) -> void:
	var requested: int = driver.consume_weapon_selection()
	if requested == -2:
		select_weapon((selected_index + 1) % weapons.size())
	elif requested >= 0:
		select_weapon(requested)

func select_weapon(index: int) -> void:
	if not active or health.is_destroyed or not driver.controls_enabled or index < 0 or index >= weapons.size():
		return
	if selected_index != index:
		_apply_selection(index)

func _apply_selection(index: int) -> void:
	selected_index = index
	for i in weapons.size():
		weapons[i].selected = i == selected_index
		weapons[i].visible = i == selected_index
	selection_changed.emit(index)

func claim_shot(weapon: Node3D) -> bool:
	if not active or health.is_destroyed or not driver.controls_enabled or weapons[selected_index] != weapon:
		return false
	var tick := Engine.get_physics_frames()
	if last_shot_tick == tick:
		return false
	last_shot_tick = tick
	return true

func _on_respawned() -> void:
	if active:
		_apply_selection(0)

func finish_combat() -> void:
	active = false
	set_physics_process(false)
	for weapon in weapons:
		weapon.stop_firing()
