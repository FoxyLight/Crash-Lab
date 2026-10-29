extends Node
## Raw root-viewport events, never global action strengths. Device slots persist
## through restart; a disconnected pad cannot steal the remaining player's slot.
signal assignments_changed
static var two_gamepads: bool = false
static var saved_devices: Array[int] = [-1, -1]
@export_range(0.0, 0.5) var deadzone: float = 0.15
var devices: Array[int] = [-1, -1]
var connected: Array[int] = []
var keys: Dictionary = {}
var mouse_fire: bool = false
var pads: Dictionary = {}
var edges: Array[Dictionary] = [{}, {}]
var await_neutral: Array[bool] = [false, true]
var slot_revisions: Array[int] = [0, 0]
var restart_edge: bool = false
var mute_edge: bool = false
const BUTTONS = [JOY_BUTTON_A, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_START]

func _ready() -> void:
	process_physics_priority = -30
	devices = saved_devices.duplicate()
	Input.joy_connection_changed.connect(_on_connection)
	_seed_keyboard()
	assign_devices(Input.get_connected_joypads())

func _input(event: InputEvent) -> void:
	route_event(event)

func route_event(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var rising: bool = event.pressed and not keys.get(code, false)
		keys[code] = event.pressed
		if rising and code == KEY_F2:
			set_two_gamepads(not two_gamepads)
			return
		if rising and code == KEY_ENTER:
			restart_edge = true
		if rising and code == KEY_M:
			mute_edge = true
		if rising and not two_gamepads:
			var action: String = {KEY_R: "reset", KEY_Q: "cycle", KEY_1: "slot1", KEY_2: "slot2"}.get(code, "")
			if not action.is_empty():
				edges[0][action] = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_fire = event.pressed
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		var slot := devices.find(event.device)
		if slot < 0 or event.device not in connected or not pads.has(event.device):
			return
		var pad: Dictionary = pads[event.device]
		if event is InputEventJoypadMotion:
			pad.axes[event.axis] = event.axis_value
		else:
			var rising: bool = event.pressed and not pad.buttons.get(event.button_index, false)
			pad.buttons[event.button_index] = event.pressed
			if rising and not await_neutral[slot]:
				var action: String = {JOY_BUTTON_DPAD_UP: "reset", JOY_BUTTON_Y: "cycle"}.get(event.button_index, "")
				if not action.is_empty():
					edges[slot][action] = true
				if event.button_index == JOY_BUTTON_START:
					restart_edge = true
				if event.button_index == JOY_BUTTON_DPAD_DOWN:
					mute_edge = true

func _on_connection(_device: int, _present: bool) -> void:
	assign_devices(Input.get_connected_joypads())

func set_two_gamepads(enabled: bool) -> void:
	if two_gamepads == enabled:
		return
	two_gamepads = enabled
	for slot in range(2):
		slot_revisions[slot] += 1
	devices = [-1, -1]
	pads.clear()
	edges = [{}, {}]
	assign_devices(connected)

func assign_devices(ids: Array) -> void:
	connected.assign(ids.duplicate())
	connected.sort()
	var previous := devices.duplicate()
	if not two_gamepads:
		devices[0] = -1
	for slot in range(2):
		if devices[slot] not in connected:
			devices[slot] = -1
	for slot in range(0 if two_gamepads else 1, 2):
		if devices[slot] >= 0:
			continue
		for id in connected:
			if id not in devices:
				devices[slot] = id
				break
	for slot in range(2):
		var id := devices[slot]
		if previous[slot] != id or (id >= 0 and not pads.has(id)):
			slot_revisions[slot] += 1
			edges[slot].clear()
			await_neutral[slot] = id >= 0
			if id >= 0:
				_seed_pad(id)
	for id in pads.keys():
		if id not in devices:
			pads.erase(id)
	saved_devices = devices.duplicate()
	assignments_changed.emit()

func _seed_pad(id: int) -> void:
	var state := {"axes": {}, "buttons": {}}
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		state.axes[axis] = Input.get_joy_axis(id, axis)
	for button in BUTTONS:
		state.buttons[button] = Input.is_joy_button_pressed(id, button)
	pads[id] = state

func _seed_keyboard() -> void:
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_F, KEY_Q, KEY_R, KEY_1, KEY_2, KEY_ENTER, KEY_M, KEY_F2]:
		keys[code] = Input.is_physical_key_pressed(code)
	mouse_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		keys.clear()
		mouse_fire = false
		edges = [{}, {}]
		restart_edge = false
		mute_edge = false
		for id in pads:
			pads[id] = {"axes": {}, "buttons": {}}
		for slot in range(2):
			slot_revisions[slot] += 1
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		_seed_keyboard()
		for slot in range(2):
			if devices[slot] >= 0:
				_seed_pad(devices[slot])
				await_neutral[slot] = true

func _physics_process(_delta: float) -> void:
	for slot in range(2):
		if not await_neutral[slot] or devices[slot] < 0:
			continue
		var state := _pad_commands(devices[slot])
		var quiet: bool = state.throttle == 0.0 and state.brake == 0.0 and state.steering == 0.0
		for held in pads[devices[slot]].buttons.values():
			quiet = quiet and not held
		if quiet:
			await_neutral[slot] = false

func analog(value: float) -> float:
	return signf(value) * clampf((absf(value) - deadzone) / maxf(0.01, 1.0 - deadzone), 0.0, 1.0)

func _pad_commands(id: int) -> Dictionary:
	var axes: Dictionary = pads[id].axes
	var buttons: Dictionary = pads[id].buttons
	return {"throttle": maxf(0.0, analog(axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0))),
		"brake": maxf(0.0, analog(axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0))),
		"steering": analog(axes.get(JOY_AXIS_LEFT_X, 0.0)),
		"handbrake": buttons.get(JOY_BUTTON_A, false), "fire": buttons.get(JOY_BUTTON_RIGHT_SHOULDER, false)}

func commands(slot: int) -> Dictionary:
	if slot == 0 and not two_gamepads:
		return {"throttle": float(keys.get(KEY_W, false)), "brake": float(keys.get(KEY_S, false)),
			"steering": float(keys.get(KEY_D, false)) - float(keys.get(KEY_A, false)),
			"handbrake": keys.get(KEY_SPACE, false), "fire": keys.get(KEY_F, false) or mouse_fire}
	if devices[slot] >= 0 and not await_neutral[slot] and pads.has(devices[slot]):
		return _pad_commands(devices[slot])
	return {"throttle": 0.0, "brake": 0.0, "steering": 0.0, "handbrake": false, "fire": false}

func consume(slot: int, action: String) -> bool:
	return edges[slot].erase(action)

func consume_selection(slot: int) -> int:
	var direct1 := consume(slot, "slot1")
	var direct2 := consume(slot, "slot2")
	var cycle := consume(slot, "cycle")
	return 0 if direct1 else (1 if direct2 else (-2 if cycle else -1))

func consume_restart() -> bool:
	var value := restart_edge
	restart_edge = false
	return value

func consume_mute() -> bool:
	var value := mute_edge
	mute_edge = false
	return value

func device_label(slot: int) -> String:
	if slot == 0 and not two_gamepads:
		return "Keyboard + mouse"
	if devices[slot] < 0:
		return "Connect a controller"
	return "Release controls to join" if await_neutral[slot] else "Controller ready"
