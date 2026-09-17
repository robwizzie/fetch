class_name DeviceInput
extends RefCounted
## Polls ONE input device and exposes move, throw/catch, dash, back and pause.
## A device is a gamepad index (0+), one of two keyboard layouts, or a virtual device that
## bots and tests drive by setting [member virtual_move] / [member virtual_buttons].
## Keeping this in one place is what makes "2-4 players on any mix of pads + keyboard" trivial.

## Gamepad (from the design board): stick/d-pad move, X = throw / catch (LT also catches), A = dash,
## A / X / Start = confirm in menus, B = back.
const KEYBOARD_WASD := -1    ## WASD, Space = throw/catch, Left Shift or E = dash, Esc = back
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
				&"throw", &"confirm":
					return Input.is_physical_key_pressed(KEY_SPACE)
				&"dash":
					return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_E)
				&"back", &"pause":
					return Input.is_physical_key_pressed(KEY_ESCAPE)
		KEYBOARD_ARROWS:
			match action:
				&"throw", &"confirm":
					return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
				&"dash":
					return Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SLASH) or Input.is_physical_key_pressed(KEY_KP_0)
				&"back":
					return Input.is_physical_key_pressed(KEY_BACKSPACE)
				&"pause":
					return Input.is_physical_key_pressed(KEY_ESCAPE)
		VIRTUAL:
			return virtual_buttons.get(action, false)
		_:
			match action:
				&"throw":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_X) or Input.is_joy_button_pressed(device, JOY_BUTTON_Y) \
						or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
						or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
				&"dash":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
				&"confirm":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
						or Input.is_joy_button_pressed(device, JOY_BUTTON_START)
				&"pause":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_START)
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
		var pad := event as InputEventJoypadButton
		if pad.button_index == JOY_BUTTON_A or pad.button_index == JOY_BUTTON_START:
			return pad.device
		# An arcade encoder carries no SDL mapping, so Godot reports raw hardware indices and
		# "button A" names nothing in particular. On a cabinet any action button should sit you
		# down; index 1 is left alone because that is what backing out uses.
		if not Input.is_joy_known(pad.device) and pad.button_index != JOY_BUTTON_B:
			return pad.device
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			return KEYBOARD_WASD
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			return KEYBOARD_ARROWS
	return NONE


## Encoder chips and sticks that show up in arcade cabinets. Godot reports the USB device
## name, and these boards are distinctive enough to match on.
const ARCADE_NAMES: Array[String] = [
	"i-pac", "ipac", "ultimarc", "xin-mo", "xinmo", "zero delay", "arcade",
	"usb encoder", "dragonrise", "generic   usb  joystick", "2 axis 8 button",
]


## True when this pad looks like an arcade cabinet rather than a console controller.
static func is_arcade(p_device: int) -> bool:
	if p_device < 0:
		return false
	if Game.arcade_hints == Game.ArcadeHints.ALWAYS:
		return true
	if Game.arcade_hints == Game.ArcadeHints.NEVER:
		return false
	var reported := Input.get_joy_name(p_device).to_lower()
	for token in ARCADE_NAMES:
		if reported.contains(token):
			return true
	return false


## True when any joined player is on a cabinet, so shared prompts can use cabinet wording.
static func any_arcade(slots: Array) -> bool:
	for slot in slots:
		if slot != null and not slot.is_bot and is_arcade(slot.device):
			return true
	return false


## One line describing how to play on this device, for the HUD and menus.
static func controls_line(p_device: int) -> String:
	match p_device:
		KEYBOARD_WASD:
			return "WASD move · Space throw / catch · E or Shift dash"
		KEYBOARD_ARROWS:
			return "Arrows move · Enter throw / catch · Ctrl dash"
		_:
			if is_arcade(p_device):
				return "Joystick move · Button 1 throw / catch · Button 2 dash"
			return "Stick move · X throw / catch · A dash"


## The button wording for one action, given who is playing.
static func button_label(action: StringName, slots: Array) -> String:
	# Before anyone has joined there are no slots to read, so fall back to what is plugged in:
	# a lobby on a cabinet must word its prompts for the cabinet from the first frame.
	var arcade := any_arcade(slots) or (slots.is_empty() and any_arcade_connected())
	match action:
		&"throw":
			return "Button 1  /  Space  /  Enter" if arcade else "X  /  Space  /  Enter"
		&"dash":
			return "Button 2  /  Shift  /  Ctrl" if arcade else "A  /  Shift  /  Ctrl"
		&"move":
			return "Joystick  /  WASD  /  Arrows" if arcade else "Stick  /  WASD  /  Arrows"
		&"confirm":
			# An unmapped encoder numbers its buttons however the board's firmware chose, so a
			# cabinet is told "any button" rather than a number that might name nothing.
			return "any button" if arcade else "A  /  Space  /  Enter"
		&"back":
			return "Button 2" if arcade else "B  /  Esc  /  Backspace"
	return ""


## True when a cabinet-looking pad is plugged in at all, whether or not anyone is using it.
static func any_arcade_connected() -> bool:
	if Game.arcade_hints == Game.ArcadeHints.ALWAYS:
		return true
	if Game.arcade_hints == Game.ArcadeHints.NEVER:
		return false
	for device in Input.get_connected_joypads():
		if is_arcade(device) or not Input.is_joy_known(device):
			return true
	return false


static func describe(p_device: int) -> String:
	match p_device:
		KEYBOARD_WASD:
			return "Keyboard · WASD"
		KEYBOARD_ARROWS:
			return "Keyboard · Arrows"
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


## Pause is distinct from B/back and A/join: neither exits an active match.
static func is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false
