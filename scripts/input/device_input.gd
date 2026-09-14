class_name DeviceInput
extends RefCounted
## Polls ONE input device and exposes a tiny set of game actions (move, throw, dash, back).
## A device is a gamepad index (0+), one of two keyboard layouts, or a virtual device that
## bots and tests drive by setting [member virtual_move] / [member virtual_buttons].
## Keeping this in one place is what makes "2-4 players on any mix of pads + keyboard" trivial.

const KEYBOARD_WASD := -1    ## WASD, Space = throw/catch, Left Shift = dash, Esc = back
const KEYBOARD_ARROWS := -2  ## Arrows, Enter = throw/catch, Right Ctrl or "/" = dash, Backspace = back
const VIRTUAL := -100        ## Scripted input for bots and automated tests
const NONE := -999

const DEADZONE := 0.25

var device: int
var virtual_move := Vector2.ZERO
var virtual_buttons: Dictionary = {}
var _prev: Dictionary = {}


func _init(p_device: int) -> void:
	device = p_device


func move_vector() -> Vector2:
	var v := Vector2.ZERO
	match device:
		KEYBOARD_WASD:
			v.x = _key_axis(KEY_D, KEY_A)
			v.y = _key_axis(KEY_S, KEY_W)
		KEYBOARD_ARROWS:
			v.x = _key_axis(KEY_RIGHT, KEY_LEFT)
			v.y = _key_axis(KEY_DOWN, KEY_UP)
		VIRTUAL:
			v = virtual_move
		_:
			v = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
			if v.length() < DEADZONE:
				v = Vector2.ZERO
			if v == Vector2.ZERO:
				v.x = _joy_axis(JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT)
				v.y = _joy_axis(JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP)
	return v.limit_length(1.0)


func is_pressed(action: StringName) -> bool:
	match action:
		&"left":
			return move_vector().x < -0.5
		&"right":
			return move_vector().x > 0.5
		&"up":
			return move_vector().y < -0.5
		&"down":
			return move_vector().y > 0.5
	match device:
		KEYBOARD_WASD:
			match action:
				&"throw":
					return Input.is_physical_key_pressed(KEY_SPACE)
				&"dash":
					return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_E)
				&"back":
					return Input.is_physical_key_pressed(KEY_ESCAPE)
		KEYBOARD_ARROWS:
			match action:
				&"throw":
					return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
				&"dash":
					return Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SLASH) or Input.is_physical_key_pressed(KEY_KP_0)
				&"back":
					return Input.is_physical_key_pressed(KEY_BACKSPACE)
		VIRTUAL:
			return virtual_buttons.get(action, false)
		_:
			match action:
				&"throw":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
				&"dash":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_B) \
						or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER) \
						or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
				&"back":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
	return false


## Edge-triggered press. Poll each action at most once per frame per DeviceInput.
func just_pressed(action: StringName) -> bool:
	var now := is_pressed(action)
	var was: bool = _prev.get(action, false)
	_prev[action] = now
	return now and not was


## Returns the device that just pressed its "join" button, or NONE.
## Join buttons: gamepad A/Start, Space (WASD layout), Enter (arrows layout).
static func join_device_from_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_START:
			return event.device
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			return KEYBOARD_WASD
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			return KEYBOARD_ARROWS
	return NONE


static func describe(p_device: int) -> String:
	match p_device:
		KEYBOARD_WASD:
			return "Keyboard: WASD + Space"
		KEYBOARD_ARROWS:
			return "Keyboard: Arrows + Enter"
		VIRTUAL:
			return "Bot"
		NONE:
			return "No device"
		_:
			return "Gamepad %d" % (p_device + 1)


func _key_axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))


func _joy_axis(positive: JoyButton, negative: JoyButton) -> float:
	return float(Input.is_joy_button_pressed(device, positive)) - float(Input.is_joy_button_pressed(device, negative))
