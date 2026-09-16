extends Node
## Synthesised one-shots. There are no audio assets in the project, so every sound is built
## from oscillators and noise at startup. Replace by pointing [method play] names at real
## AudioStreams (drop files in res://assets/audio/ and register them in [member _streams]).
##
## Sounds are layered rather than single tones: an impact gets a transient AND a body, a
## whoosh gets filtered noise, so they read as events instead of beeps.

const RATE := 44100
const VOICES := 16
const BUS := "SFX"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var enabled := true


func _ready() -> void:
	_ensure_bus()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_players.append(player)
	_build()


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")


func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(sound_name):
		return
	for player in _players:
		if not player.playing:
			player.stream = _streams[sound_name]
			player.pitch_scale = pitch
			player.volume_db = volume_db
			player.play()
			return


# ---------------------------------------------------------------- the kit

func _build() -> void:
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
	return randf_range(-1.0, 1.0)


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
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0 * 0.8))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
