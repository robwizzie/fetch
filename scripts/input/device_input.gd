class_name DeviceInput
extends RefCounted
## Polls ONE input device and exposes move, throw/catch, dash, back and pause.
## A device is a gamepad index (0+), one of two keyboard layouts, or a virtual device that
## bots and tests drive by setting [member virtual_move] / [member virtual_buttons].
## Keeping this in one place is what makes "2-4 players on any mix of pads + keyboard" trivial.

## Gamepad (from the design board): stick/d-pad move, X = throw / catch (LT also catches), A = dash,
## A / X / Start = confirm in menus, B = back.
const KEYBOARD_WASD := -1    ## WASD, Space = throw/catch, Shift (either) = dash, Esc = back
const KEYBOARD_ARROWS := -2  ## Arrows, Enter = throw/catch, "/" = dash, Backspace = back
const VIRTUAL := -100        ## Scripted input for bots and automated tests
const NONE := -999

const DEADZONE := 0.25

var device: int
var virtual_move := Vector2.ZERO
var virtual_buttons: Dictionary = {}
var _prev: Dictionary = {}
## Release edges keep their own history so a frame can ask for both edges of one button.
var _prev_release: Dictionary = {}


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
			else:
				v = v.normalized() * inverse_lerp(DEADZONE, 1.0, minf(v.length(), 1.0))
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
					# Either Shift: whichever one the hand finds. One key name on the prompt, though -
					# "Shift or E" read as a two-key chord.
					return Input.is_physical_key_pressed(KEY_SHIFT)
				&"back", &"pause":
					return Input.is_physical_key_pressed(KEY_ESCAPE)
				&"bark":
					return Input.is_physical_key_pressed(KEY_Q)
		KEYBOARD_ARROWS:
			match action:
				&"throw", &"confirm":
					return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
				&"dash":
					# "/" sits under the right hand beside Enter and "." (bark), and is not a Shift,
					# which the WASD player now owns on both sides.
					return Input.is_physical_key_pressed(KEY_SLASH)
				&"back":
					return Input.is_physical_key_pressed(KEY_BACKSPACE)
				&"pause":
					return Input.is_physical_key_pressed(KEY_ESCAPE)
				&"bark":
					return Input.is_physical_key_pressed(KEY_PERIOD)
		VIRTUAL:
			return virtual_buttons.get(action, false)
		_:
			match action:
				&"throw":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
						or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
						or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.5
				&"bark":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
				&"dash":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
				&"confirm":
					if not Input.is_joy_known(device):
						return _any_arcade_button(device)
					return Input.is_joy_button_pressed(device, JOY_BUTTON_A) or Input.is_joy_button_pressed(device, JOY_BUTTON_X) \
						or Input.is_joy_button_pressed(device, JOY_BUTTON_START)
				&"pause":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_START)
				&"back":
					return Input.is_joy_button_pressed(device, JOY_BUTTON_B) or Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
	return false


## Godot reports a hat switch as the four d-pad buttons; those move, they never select.
static func is_dpad_button(index: int) -> bool:
	return index >= JOY_BUTTON_DPAD_UP and index <= JOY_BUTTON_DPAD_RIGHT


## An unmapped arcade encoder confirms the way it joins: any action button but the back one, so
## the button that sat a player down can also ready them up.
static func _any_arcade_button(pad: int) -> bool:
	for index in range(0, 16):
		if index != JOY_BUTTON_B and index != JOY_BUTTON_BACK and not is_dpad_button(index) and Input.is_joy_button_pressed(pad, index):
			return true
	return false


## Edge-triggered press. Poll each action at most once per frame per DeviceInput.
func just_pressed(action: StringName) -> bool:
	var now := is_pressed(action)
	var was: bool = _prev.get(action, false)
	_prev[action] = now
	return now and not was


## Edge-triggered release, for buttons that are held: charging a throw ends when it comes up.
## Poll each action at most once per frame per DeviceInput.
func just_released(action: StringName) -> bool:
	var now := is_pressed(action)
	var was: bool = _prev_release.get(action, false)
	_prev_release[action] = now
	return was and not now


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
		if not Input.is_joy_known(pad.device) and pad.button_index != JOY_BUTTON_B and not is_dpad_button(pad.button_index):
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


## Which printed labels a pad has. Godot maps pad buttons by POSITION (JOY_BUTTON_X is always
## the left face button), so the same binding is "X" on an Xbox pad, "Square" on a PlayStation
## pad and "Y" on a Switch pad. Prompts have to say what is printed on the plastic.
enum PadFamily { XBOX, PLAYSTATION, NINTENDO, ARCADE }

const SONY_VENDOR := 0x054C
const NINTENDO_VENDOR := 0x057E


static func pad_family(p_device: int) -> PadFamily:
	if is_arcade(p_device):
		return PadFamily.ARCADE
	var reported := Input.get_joy_name(p_device).to_lower()
	var info := Input.get_joy_info(p_device)
	var vendor := int(info.get("vendor_id", 0))
	if vendor == SONY_VENDOR or ["ps3", "ps4", "ps5", "dualshock", "dualsense", "playstation", "sony"].any(func(t: String) -> bool: return reported.contains(t)):
		return PadFamily.PLAYSTATION
	if vendor == NINTENDO_VENDOR or ["nintendo", "switch", "joy-con", "joycon", "pro controller"].any(func(t: String) -> bool: return reported.contains(t)):
		return PadFamily.NINTENDO
	return PadFamily.XBOX


## The words for one action on one device, exactly as printed on it. Every binding
## [method is_pressed] accepts is covered by the primary label or the alternative after "or".
static func glyph(action: StringName, p_device: int) -> String:
	match p_device:
		KEYBOARD_WASD:
			return {&"move": "WASD", &"throw": "Space", &"dash": "Shift", &"confirm": "Space",
				&"back": "Esc", &"pause": "Esc", &"bark": "Q"}.get(action, "")
		KEYBOARD_ARROWS:
			return {&"move": "Arrow keys", &"throw": "Enter", &"dash": "/", &"confirm": "Enter",
				&"back": "Backspace", &"pause": "Esc", &"bark": "."}.get(action, "")
		VIRTUAL, NONE:
			return ""
	return pad_glyph(action, pad_family(p_device))


## The printed label for an action on a kind of pad. Split out so it can be checked without
## the physical controller plugged in.
static func pad_glyph(action: StringName, family: PadFamily) -> String:
	match family:
		PadFamily.ARCADE:
			# An unmapped encoder numbers its buttons however its firmware chose, so confirm is
			# "any button" rather than a number that might name nothing.
			return {&"move": "Joystick", &"throw": "Button 1", &"dash": "Button 2", &"confirm": "any button",
				&"back": "Button 2", &"pause": "Start", &"bark": "Button 4"}.get(action, "")
		PadFamily.PLAYSTATION:
			return {&"move": "Left stick", &"throw": "Square or L2/R2", &"dash": "Cross or R1", &"confirm": "Cross",
				&"back": "Circle", &"pause": "Options", &"bark": "Triangle"}.get(action, "")
		PadFamily.NINTENDO:
			return {&"move": "Left stick", &"throw": "Y or ZL/ZR", &"dash": "B or R", &"confirm": "B",
				&"back": "A", &"pause": "+", &"bark": "X"}.get(action, "")
	return {&"move": "Left stick", &"throw": "X or LT/RT", &"dash": "A or RB", &"confirm": "A",
		&"back": "B", &"pause": "Menu", &"bark": "Y"}.get(action, "")


## Just the main button, for short prompts: "X", not "X or LT/RT".
static func short_glyph(action: StringName, p_device: int) -> String:
	return glyph(action, p_device).get_slice(" or ", 0)


## A short name for the device, for labelling a line of controls.
static func family_name(p_device: int) -> String:
	match p_device:
		KEYBOARD_WASD:
			return "Keyboard (WASD)"
		KEYBOARD_ARROWS:
			return "Keyboard (Arrows)"
	match pad_family(p_device):
		PadFamily.ARCADE:
			return "Arcade stick"
		PadFamily.PLAYSTATION:
			return "PlayStation pad"
		PadFamily.NINTENDO:
			return "Switch pad"
	return "Xbox-style pad"


## One line describing how to play on this device, for the HUD and menus.
static func controls_line(p_device: int) -> String:
	return "%s move · %s throw / catch (hold for power) · %s dash · %s bark · %s pause" % [
		glyph(&"move", p_device), glyph(&"throw", p_device), glyph(&"dash", p_device), glyph(&"bark", p_device), glyph(&"pause", p_device)]


## The devices prompts should speak to: the humans who have joined, or before anyone has,
## everything that could join (both keyboard layouts and every connected pad).
static func prompt_devices(slots: Array) -> Array[int]:
	var devices: Array[int] = []
	for slot in slots:
		if slot != null and not slot.is_bot and slot.device != VIRTUAL and slot.device != NONE and not devices.has(slot.device):
			devices.append(slot.device)
	if devices.is_empty():
		devices.append_array(Input.get_connected_joypads())
		devices.append(KEYBOARD_WASD)
		devices.append(KEYBOARD_ARROWS)
	return devices


## The button wording for one action, given who is playing: only the controls actually in
## people's hands, each named as printed on it, without repeats.
static func button_label(action: StringName, slots: Array) -> String:
	var words: Array[String] = []
	for device in prompt_devices(slots):
		var word := short_glyph(action, device)
		if not word.is_empty() and not words.has(word):
			words.append(word)
	return "  /  ".join(words)


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
