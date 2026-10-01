extends Node
## One-shot sound effects. Recorded sounds come first: a folder under res://assets/audio/sfx/
## named after a sound (paw/, whack/, ...) holds its takes, and one is picked at random each time
## it plays. Anything without a folder falls back to a sound synthesised at startup, so the dog
## voices and comic sounds (bark, squeak, boing) still work. Adding a take is dropping in a file.
##
## Every recorded sound is CC0: Kenney's packs (assets/audio/KENNEY_LICENSE.txt) plus single
## takes from Freesound and OpenGameArt. assets/audio/CREDITS.md lists where each file came from.
##
## Barks have a voice per breed: bark_<breed>/ holds that dog's own takes, bark/ is the shared
## fallback, and with neither the synthesised bark is pitched to the dog's size. See [method bark].
##
## Sounds are layered rather than single tones: an impact gets a transient AND a body, a
## whoosh gets filtered noise, so they read as events instead of beeps.

const RATE := 44100
const VOICES := 16
const BUS := "SFX"

## Only this much stereo spread: a couch game is heard across a room, and hard-panned
## sounds read as coming from one speaker rather than from one side of the arena.
const MAX_PAN := 0.6
const ASSET_DIR := "res://assets/audio/sfx/"
## Level trims for recorded takes, in dB. Most files are mastered hot compared with the
## synthesised kit, and footsteps in particular must sit under everything else. The SFX bus
## limiter catches what a boosted take and a loud call add up to.
const ASSET_GAIN := {
	"paw": -9.0, "paw_hard": -9.0, "splat": -4.0, "dash": -2.0, "charge": -8.0, "tick": -2.0,
	"bounce": -3.0, "bounce_bone": -3.0, "bounce_disc": -3.0, "ui": -6.0, "ui_back": -6.0,
	# The barks are matched to one loudness when cut; the yappy ones sit a hair lower.
	"bark": -4.0, "bark_labrador": -4.0, "bark_pitbull": -4.0, "bark_corgi": -5.0,
	"bark_dachshund": -5.0, "bark_golden": -4.0, "bark_spaniel": -4.0,
	# The glove-smack catch and the jingle are mastered quiet; a catch has to land as loud as a hit.
	"catch": 3.0, "fanfare": 8.0,
	"bonk": -5.0, "whistle": -9.0, "squeak": -7.0, "throw": -6.0, "blast": -3.0,
}
## Each breed's bark: [its folder suffix, pitch on its own takes, pitch on the shared bark].
## A breed with its own takes is only nudged - the recording already is that dog - so the big
## dogs sit a touch lower and the little ones a touch higher. Borrowing the shared bark (or the
## synthesised one), the size has to come from pitch alone, so the spread is much wider.
const BREED_VOICES := {
	DogData.Breed.LABRADOR: ["labrador", 1.0, 0.95],
	DogData.Breed.PITBULL: ["pitbull", 0.92, 0.82],
	DogData.Breed.CORGI: ["corgi", 1.06, 1.35],
	DogData.Breed.DACHSHUND: ["dachshund", 1.04, 1.3],
	DogData.Breed.GOLDEN: ["golden", 0.94, 1.0],
	DogData.Breed.SPANIEL: ["spaniel", 1.0, 1.15],
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _panners: Array[AudioEffectPanner] = []
var enabled := true
## Footsteps change with the floor: set by the arena as it loads.
var hard_floor := false
var _rng := RandomNumberGenerator.new()
var _last_played: Dictionary = {}
## Alternate takes of the most repeated sounds, so a run is not one sample on a loop.
var _variants: Dictionary = {}
## Recorded takes by sound name, loaded from [constant ASSET_DIR].
var _pools: Dictionary = {}


func _ready() -> void:
	_rng.seed = 982451653
	_ensure_bus()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = _voice_bus(i)
		add_child(player)
		_players.append(player)
	_build()
	_load_assets()


func _load_assets() -> void:
	for folder in ResourceLoader.list_directory(ASSET_DIR):
		if not folder.ends_with("/"):
			continue
		var takes: Array[AudioStream] = []
		for file in ResourceLoader.list_directory(ASSET_DIR + folder):
			if file.get_extension() in ["ogg", "wav", "mp3"]:
				var stream := load(ASSET_DIR + folder + file) as AudioStream
				if stream != null:
					takes.append(stream)
		if not takes.is_empty():
			_pools[folder.trim_suffix("/")] = takes


## Each voice gets a tiny bus with its own panner, so sounds can sit where they happened.
func _voice_bus(i: int) -> String:
	var bus_name := "%s%d" % [BUS, i]
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS)
		AudioServer.add_bus_effect(index, AudioEffectPanner.new())
	_panners.append(AudioServer.get_bus_effect(index, 0) as AudioEffectPanner)
	return bus_name


## A room is a little live, a lawn is not. Called by the arena as it loads.
func set_room(indoor: bool, hard: bool) -> void:
	hard_floor = hard
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		return
	var reverb := AudioServer.get_bus_effect(index, 1) as AudioEffectReverb
	reverb.room_size = 0.38 if indoor else 0.2
	reverb.damping = 0.6 if indoor else 0.85
	reverb.wet = 0.12 if indoor else 0.04
	reverb.dry = 1.0


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.add_bus_effect(index, AudioEffectLimiter.new())
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.2
	reverb.wet = 0.04
	reverb.predelay_msec = 12.0
	AudioServer.add_bus_effect(index, reverb, 1)


## Like [method play], panned toward where [param world] sits on screen.
func play_at(sound_name: String, world: Vector3, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var pan := 0.0
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera != null and not camera.is_position_behind(world):
		var width := maxf(viewport.get_visible_rect().size.x, 1.0)
		pan = clampf((camera.unproject_position(world).x / width) * 2.0 - 1.0, -1.0, 1.0) * MAX_PAN
	play(sound_name, pitch, volume_db, pan)


func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0, pan: float = 0.0) -> void:
	if not enabled:
		return
	if sound_name == "paw" and hard_floor:
		sound_name = "paw_hard"
	var stream: AudioStream = null
	if _pools.has(sound_name):
		var takes: Array = _pools[sound_name]
		stream = takes[_rng.randi() % takes.size()]
		volume_db += ASSET_GAIN.get(sound_name, 0.0)
	else:
		var options: Array = _variants.get(sound_name, [])
		if not options.is_empty():
			stream = _streams[options[_rng.randi() % options.size()]]
		elif _streams.has(sound_name):
			stream = _streams[sound_name]
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var interval := 70 if sound_name.begins_with("paw") else (35 if sound_name.begins_with("bounce") else 15)
	if now - int(_last_played.get(sound_name, -1000)) < interval:
		return
	_last_played[sound_name] = now
	var priority := 3 if sound_name in ["bonk", "hit", "catch", "shield", "blast", "whistle", "fanfare", "whack"] else (0 if sound_name.begins_with("paw") else 1)
	var chosen: AudioStreamPlayer
	for player in _players:
		if not player.playing:
			chosen = player
			break
		if int(player.get_meta("priority", 0)) < priority and (chosen == null or int(player.get_meta("started", 0)) < int(chosen.get_meta("started", 0))):
			chosen = player
	if chosen == null:
		return
	chosen.stop()
	chosen.stream = stream
	var variation := _rng.randf_range(0.96, 1.04) if priority < 3 else 1.0
	chosen.pitch_scale = clampf(pitch * variation, 0.5, 2.0)
	chosen.volume_db = volume_db - 3.0
	_panners[_players.find(chosen)].pan = pan
	chosen.set_meta("priority", priority)
	chosen.set_meta("started", now)
	chosen.play()


## The sound a breed barks with: its own recorded takes when it has them, else the shared bark
## (recorded if bark/ has takes, synthesised if not).
func bark_sound(breed: int) -> String:
	var voice: Array = BREED_VOICES.get(breed, ["", 1.0, 1.0])
	var own := "bark_%s" % voice[0]
	return own if _pools.has(own) else "bark"


## A dog's bark in its breed's voice. [param pitch] is the mood on top of the voice: up for a
## happy revive, down for a dazed yelp. Pass [param world] to pan it like [method play_at].
func bark(breed: int, pitch: float = 1.0, volume_db: float = 0.0, world: Vector3 = Vector3.INF) -> void:
	var voice: Array = BREED_VOICES.get(breed, ["", 1.0, 1.0])
	var sound := bark_sound(breed)
	var base: float = voice[2] if sound == "bark" else voice[1]
	if world == Vector3.INF:
		play(sound, base * pitch, volume_db)
	else:
		play_at(sound, world, base * pitch, volume_db)


func toy_impact(id: StringName, speed: float, world: Vector3 = Vector3.INF) -> void:
	var sound := "bounce_bone" if id == &"bone" else ("bounce_disc" if id == &"frisbee" else "bounce")
	# Harder hits are louder AND a touch lower, which is what reads as weight.
	var force := clampf(speed / 25.0, 0.0, 1.0)
	if world == Vector3.INF:
		play(sound, lerpf(1.08, 0.94, force), lerpf(-16.0, -5.0, force))
	else:
		play_at(sound, world, lerpf(1.08, 0.94, force), lerpf(-16.0, -5.0, force))


# ---------------------------------------------------------------- the kit

func _build() -> void:
	# Short organic contacts sit under the action, while powers each have their own signature.
	# Four takes each: soft pads on grass and sand, a claw click on boards and tiles.
	_variants["paw"] = []
	_variants["paw_hard"] = []
	for take in 4:
		var body_hz := 120.0 + take * 14.0
		var soft := "paw_%d" % take
		_streams[soft] = _render(0.08, func(t: float, _d: float) -> float:
			return (_noise() * 0.42 + sin(TAU * body_hz * t) * 0.45) * exp(-t * 58.0), 0.1)
		_variants["paw"].append(soft)
		var hard := "paw_hard_%d" % take
		var click_hz := 2100.0 + take * 260.0
		_streams[hard] = _render(0.07, func(t: float, _d: float) -> float:
			var click := sin(TAU * click_hz * t) * exp(-t * 260.0) * 0.35
			return click + (_noise() * 0.18 + sin(TAU * (body_hz + 40.0) * t) * 0.4) * exp(-t * 70.0), 0.5)
		_variants["paw_hard"].append(hard)
	_streams["paw_hard"] = _streams["paw_hard_0"]
	# A swipe: a short air cut into a padded thwack.
	_streams["whack"] = _render(0.2, func(t: float, d: float) -> float:
		var p := t / d
		var swish := _noise() * sin(PI * minf(1.0, p * 3.0)) * (1.0 - smoothstep(0.25, 0.4, p)) * 0.45
		var thwack := 0.0
		if t > 0.055:
			var local := t - 0.055
			thwack = (sin(TAU * (210.0 * exp(-local * 18.0) + 80.0) * local) * 0.7 + _noise() * exp(-local * 90.0) * 0.5) * exp(-local * 22.0)
		return swish + thwack, 0.55)
	# Seeing stars: a woozy, wobbling slide down.
	_streams["dizzy"] = _render(0.62, func(t: float, d: float) -> float:
		var p := t / d
		var hz := (1250.0 - 520.0 * p) * (1.0 + sin(TAU * 11.0 * t) * 0.06)
		var tweet := sin(TAU * hz * t) * (0.6 + 0.4 * sin(TAU * 6.0 * t))
		return tweet * sin(PI * p) * 0.3, 0.8)
	# Mud: a wet, low splat.
	_streams["splat"] = _render(0.2, func(t: float, d: float) -> float:
		var p := t / d
		var squelch := sin(TAU * (160.0 - 70.0 * p) * t) * exp(-t * 20.0) * 0.5
		var wet := _noise() * exp(-t * 32.0) * 0.45
		return squelch + wet, 0.18)
	# Full wind-up: a bright ring so a held throw is readable by ear alone.
	_streams["charged"] = _render(0.3, func(t: float, d: float) -> float:
		var p := t / d
		return (sin(TAU * 1318.0 * t) * 0.4 + sin(TAU * 1976.0 * t) * 0.18) * exp(-p * 4.5) * minf(1.0, t * 400.0), 1.0)
	# A knocked-out body landing: a heavy, dull thump.
	_streams["land"] = _render(0.28, func(t: float, _d: float) -> float:
		return (sin(TAU * (85.0 * exp(-t * 6.0) + 45.0) * t) * 0.8 + _noise() * exp(-t * 60.0) * 0.3) * exp(-t * 14.0), 0.3)
	# Through a portal: a rising, bubbling shimmer.
	_streams["warp"] = _render(0.34, func(t: float, d: float) -> float:
		var p := t / d
		var hz := 300.0 + 900.0 * p * p
		var bubble := 1.0 + sin(TAU * 30.0 * t) * 0.3
		return (sin(TAU * hz * bubble * t) * 0.4 + sin(TAU * hz * 1.5 * t) * 0.15) * sin(PI * p), 0.7)
	_streams["bounce_bone"] = _render(0.16, func(t: float, _d: float) -> float:
		return (sin(TAU * 720.0 * t) * 0.4 + sin(TAU * 1193.0 * t) * 0.18 + _noise() * exp(-t * 80.0) * 0.55) * exp(-t * 28.0), 0.65)
	_streams["bounce_disc"] = _render(0.18, func(t: float, _d: float) -> float:
		return (sin(TAU * 460.0 * t) * 0.38 + sin(TAU * 893.0 * t) * 0.15 + _noise() * 0.24) * exp(-t * 32.0), 0.38)
	_streams["shield"] = _render(0.32, func(t: float, d: float) -> float:
		return (sin(TAU * 930.0 * t) * 0.4 + sin(TAU * 1470.0 * t) * 0.22 + _noise() * exp(-t * 24.0) * 0.35) * exp(-t * 12.0) * (1.0 - t / d), 0.6)
	_streams["fuse"] = _render(0.42, func(t: float, d: float) -> float:
		var p := t / d
		var pulse := pow(maxf(0.0, sin(TAU * (8.0 * t + 6.0 * t * t))), 3.0)
		return sin(TAU * (650.0 * t + 500.0 * t * t)) * pulse * 0.28 * (1.0 - p * 0.25), 0.7)
	_streams["blast"] = _render(0.40, func(t: float, d: float) -> float:
		var puff := _noise() * exp(-t * 14.0) * 0.5
		var thump := sin(TAU * (95.0 * t + 30.0 * (1.0 - exp(-t * 12.0)))) * exp(-t * 16.0) * 0.55
		var squeak := sin(TAU * (900.0 * t - 620.0 * t * t)) * sin(PI * t / d) * exp(-t * 8.0) * 0.22
		return puff + thump + squeak, 0.22)
	_streams["charge"] = _render(0.055, func(t: float, d: float) -> float:
		return (sin(TAU * 320.0 * t) * 0.35 + _noise() * 0.15) * sin(PI * t / d) * exp(-t * 35.0), 0.4)
	# A toy leaving the mouth: air first, then a short tonal "fwip".
	_streams["throw"] = _render(0.26, func(t: float, d: float) -> float:
		var p := t / d
		var air := _noise() * exp(-p * 5.0) * (1.0 - p) * 0.55
		var tone := sin(TAU * (240.0 + 900.0 * p) * t) * exp(-p * 6.0) * 0.30
		return air + tone, 0.62)

	# Wall contact: a click on top of a short pitched body.
	_streams["bounce"] = _render(0.20, func(t: float, _d: float) -> float:
		var click := _noise() * exp(-t * 150.0) * 0.35
		var body := sin(TAU * (168.0 * exp(-t * 3.0) + 90.0) * t) * exp(-t * 24.0) * 0.7
		return click + body, 0.8)

	# A satisfying catch: a rising pop with a sparkle on top.
	_streams["catch"] = _render(0.26, func(t: float, d: float) -> float:
		var p := t / d
		var pop := sin(TAU * (520.0 + 420.0 * p) * t) * exp(-p * 5.5) * 0.65
		var sparkle := sin(TAU * 1760.0 * t) * exp(-p * 13.0) * 0.22
		return pop + sparkle, 0.9)

	# Elimination: a thud, a comedy descending boing, and a bit of grit.
	_streams["bonk"] = _render(0.46, func(t: float, d: float) -> float:
		var p := t / d
		var thud := sin(TAU * (150.0 * exp(-t * 7.0) + 58.0) * t) * exp(-t * 9.0) * 0.8
		var boing := sin(TAU * (420.0 * exp(-t * 3.4) + 110.0) * t) * exp(-t * 5.0) * 0.32
		var grit := _noise() * exp(-t * 40.0) * 0.25
		return thud + boing + grit, 0.7)

	# Dash: a short filtered whoosh that sweeps past.
	_streams["dash"] = _render(0.22, func(t: float, d: float) -> float:
		var p := t / d
		var bell := sin(PI * p)
		return _noise() * bell * 0.6, 0.45)

	# Picking a toy up: a friendly two-note lift.
	_streams["pickup"] = _render(0.17, func(t: float, d: float) -> float:
		var p := t / d
		var hz := 587.0 if p < 0.45 else 880.0
		return sin(TAU * hz * t) * exp(-fposmod(t, 0.077) * 26.0) * (1.0 - p * 0.5) * 0.6, 0.95)

	# Referee whistle: two detuned tones, a trill, and breath.
	_streams["whistle"] = _render(0.46, func(t: float, d: float) -> float:
		var p := t / d
		var trill := 1.0 + sin(TAU * 26.0 * t) * 0.035
		var a := sin(TAU * 2350.0 * trill * t)
		var b := sin(TAU * 2560.0 * trill * t) * 0.7
		var breath := _noise() * 0.16
		var envelope := minf(1.0, p * 14.0) * clampf(1.0 - (p - 0.7) / 0.3, 0.0, 1.0)
		return (a + b + breath) * envelope * 0.34, 1.0)

	# Countdown click.
	_streams["tick"] = _render(0.09, func(t: float, d: float) -> float:
		var p := t / d
		return (sin(TAU * 660.0 * t) * 0.7 + _noise() * 0.2) * exp(-p * 7.0) * (1.0 - p), 1.0)

	# Round or match won: a rising arpeggio that lands on a chord.
	_streams["fanfare"] = _render(0.85, func(t: float, d: float) -> float:
		var p := t / d
		var steps: Array = [523.0, 659.0, 784.0, 1046.0]
		var index := mini(int(t / 0.10), 3)
		var lead: float = steps[index]
		var sample := sin(TAU * lead * t) * 0.5
		if t > 0.40:
			# The whole chord rings out under the last note.
			for hz in steps:
				sample += sin(TAU * float(hz) * t) * 0.18
		return sample * exp(-p * 1.6) * (1.0 - p * 0.35) * 0.55, 1.0)

	# A dog bark: a voiced burst with a fast pitch drop, in two syllables.
	_streams["bark"] = _render(0.30, func(t: float, _d: float) -> float:
		var gate := 1.0 if t < 0.085 else (0.85 if t > 0.12 and t < 0.21 else 0.0)
		if gate <= 0.0:
			return 0.0
		var local := t if t < 0.085 else t - 0.12
		var hz := 340.0 * exp(-local * 9.0) + 130.0
		var voiced := sin(TAU * hz * t) * 0.5 + sin(TAU * hz * 2.0 * t) * 0.22 + sin(TAU * hz * 3.0 * t) * 0.12
		var rasp := _noise() * 0.18
		return (voiced + rasp) * exp(-local * 13.0) * gate, 0.75)

	# Treat collected: a bright three-note sparkle.
	_streams["treat"] = _render(0.34, func(t: float, d: float) -> float:
		var p := t / d
		var steps: Array = [784.0, 1046.0, 1318.0]
		var index := mini(int(t / 0.085), 2)
		var hz: float = steps[index]
		var shimmer := sin(TAU * hz * 2.0 * t) * 0.18
		return (sin(TAU * hz * t) * 0.55 + shimmer) * exp(-fposmod(t, 0.085) * 20.0) * (1.0 - p * 0.4) * 0.6, 1.0)

	# Squeaky toy: high, warbling, and rising.
	_streams["squeak"] = _render(0.24, func(t: float, d: float) -> float:
		var p := t / d
		var warble := 1.0 + sin(TAU * 38.0 * t) * 0.16
		var hz := (1150.0 + 700.0 * p) * warble
		return sin(TAU * hz * t) * sin(PI * p) * 0.5, 1.0)

	# Menu blips: confirm rises, move is a quiet tap, back falls.
	_streams["ui"] = _render(0.09, func(t: float, d: float) -> float:
		var p := t / d
		return sin(TAU * (620.0 + 260.0 * p) * t) * exp(-p * 5.0) * 0.4, 1.0)
	_streams["ui_move"] = _render(0.06, func(t: float, d: float) -> float:
		var p := t / d
		return sin(TAU * 480.0 * t) * exp(-p * 7.0) * 0.28, 1.0)
	_streams["ui_back"] = _render(0.11, func(t: float, d: float) -> float:
		var p := t / d
		return sin(TAU * (520.0 - 200.0 * p) * t) * exp(-p * 5.0) * 0.34, 1.0)

	# Studio bumper sting: a soft swell that resolves.
	_streams["sting"] = _render(1.5, func(t: float, d: float) -> float:
		var p := t / d
		var swell := minf(1.0, p * 3.2) * exp(-p * 1.5)
		var sample := sin(TAU * 196.0 * t) * 0.34
		sample += sin(TAU * 293.7 * t) * 0.26
		sample += sin(TAU * 392.0 * t) * 0.20
		sample += sin(TAU * 587.3 * t) * 0.12 * clampf((p - 0.25) * 3.0, 0.0, 1.0)
		return sample * swell * 0.7, 1.0)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


## Renders a generator into a stream. [param brightness] is a one-pole lowpass coefficient:
## 1.0 leaves the signal alone, lower values round off noise and square edges.
func _render(duration: float, generator: Callable, brightness: float = 1.0) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		samples[i] = generator.call(t, duration)
	if brightness < 0.999:
		var previous := 0.0
		for i in count:
			previous = previous + (samples[i] - previous) * brightness
			samples[i] = previous
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		# Soft clip keeps layered peaks from crackling.
		var value := samples[i]
		value = value / (1.0 + absf(value) * 0.3)
		var edge := minf(1.0, float(i) / 100.0) * minf(1.0, float(count - 1 - i) / 220.0)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0 * 0.8 * edge))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
