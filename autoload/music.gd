extends Node
## Procedural soundtrack. There are no audio assets in the project, so the tracks are
## sequenced and rendered at startup the same way [Sfx] synthesises its one-shots.
##
## Rendering happens on a worker thread: a track is ~17 s of audio and building it on the
## main thread would stall the first frame. Calls to [method play] before the render lands
## are remembered and honoured once it does.

const RATE := 44100
const BUS := "Music"
## Sequencer resolution: one step is a sixteenth note.
const STEPS_PER_BAR := 16

var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			stop(0.25)
		elif not _wanted.is_empty():
			play(_wanted)

var _tracks: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current := ""
var _wanted := ""
var _thread: Thread
var _ducked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = -60.0
		add_child(player)
		_players.append(player)
	# Headless runs (the test suites) never need a soundtrack, and skipping the render keeps
	# the suites fast.
	if DisplayServer.get_name() == "headless":
		return
	_thread = Thread.new()
	_thread.start(_render_all)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, "Master")


func _process(_delta: float) -> void:
	if _thread == null or not _thread.is_started() or _thread.is_alive():
		return
	var rendered: Dictionary = _thread.wait_to_finish()
	_thread = null
	for key in rendered:
		_tracks[key] = _to_stream(rendered[key])
	if not _wanted.is_empty():
		play(_wanted, 1.4)


## Crossfades to a track. Repeating the current track is a no-op, so screens can all ask for
## the same music without restarting it on every scene change.
func play(track: String, fade: float = 1.1) -> void:
	_wanted = track
	if not enabled or _current == track or not _tracks.has(track):
		return
	_current = track
	var incoming := 1 - _active
	var outgoing := _players[_active]
	var target := _players[incoming]
	target.stream = _tracks[track]
	target.volume_db = -60.0
	target.play()
	_active = incoming
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "volume_db", _level(), fade)
	tween.tween_property(outgoing, "volume_db", -60.0, fade)
	tween.chain().tween_callback(outgoing.stop)


func stop(fade: float = 0.8) -> void:
	_current = ""
	for player in _players:
		if not player.playing:
			continue
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, fade)
		tween.tween_callback(player.stop)


## Pulls the music back for a moment so a knockout or a result lands in the clear.
func duck(seconds: float = 1.1, amount: float = 9.0) -> void:
	if _ducked or not enabled:
		return
	var player := _players[_active]
	if not player.playing:
		return
	_ducked = true
	var tween := create_tween()
	tween.tween_property(player, "volume_db", _level() - amount, 0.12)
	tween.tween_interval(seconds)
	tween.tween_property(player, "volume_db", _level(), 0.5)
	tween.tween_callback(func() -> void: _ducked = false)


func _level() -> float:
	return -9.0


# ---------------------------------------------------------------- rendering

func _render_all() -> Dictionary:
	return {
		"menu": _render(_menu_spec()),
		"match": _render(_match_spec()),
		"victory": _render(_victory_spec()),
	}


## A track is a bar-by-bar chord chart plus a handful of pattern flags. Every voice writes
## into one buffer; tails wrap around the end so the loop joins without a seam.
func _menu_spec() -> Dictionary:
	return {
		"bpm": 104.0,
		# I - V - vi - IV, the warm one. Semitones relative to C.
		"chords": [0, 7, 9, 5, 0, 7, 5, 7],
		"bass_octave": -24,
		"lead": true,
		"lead_gain": 0.20,
		"kick": [0, 8],
		"snare": [4, 12],
		"hat_every": 4,
		"hat_gain": 0.05,
		"chord_gain": 0.13,
		"bass_gain": 0.26,
	}


func _match_spec() -> Dictionary:
	return {
		"bpm": 138.0,
		"chords": [9, 5, 0, 7, 9, 5, 7, 7],
		"bass_octave": -24,
		"lead": false,
		"lead_gain": 0.0,
		"kick": [0, 6, 8, 14],
		"snare": [4, 12],
		"hat_every": 2,
		"hat_gain": 0.07,
		"chord_gain": 0.11,
		"bass_gain": 0.30,
	}


func _victory_spec() -> Dictionary:
	return {
		"bpm": 120.0,
		"chords": [5, 7, 0, 0, 5, 7, 0, 0],
		"bass_octave": -24,
		"lead": true,
		"lead_gain": 0.24,
		"kick": [0, 8],
		"snare": [4, 12],
		"hat_every": 2,
		"hat_gain": 0.06,
		"chord_gain": 0.15,
		"bass_gain": 0.26,
	}


func _render(spec: Dictionary) -> PackedFloat32Array:
	var bpm: float = spec.bpm
	var chords: Array = spec.chords
	var step_seconds := 60.0 / bpm / 4.0
	var bars := chords.size()
	var total := int(step_seconds * STEPS_PER_BAR * bars * RATE)
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

	for bar in bars:
		var root: int = chords[bar]
		var bar_start := float(bar * STEPS_PER_BAR) * step_seconds
		# Bass: root on the beat with a lift into the next bar.
		for beat in 4:
			var at := bar_start + float(beat * 4) * step_seconds
			var note: int = root + spec.bass_octave + (7 if beat == 3 else 0)
			_voice(buffer, at, step_seconds * 4.6, _hz(note), spec.bass_gain, 1, 0.006, 2.9)
		# Chord pad on the off-beats, a triad above the bass.
		for offset in [2, 6, 10, 14]:
			var at := bar_start + float(offset) * step_seconds
			for interval in [0, 4, 7]:
				var shade: int = 3 if root == 9 else 4
				var tone: int = root + (0 if interval == 0 else (shade if interval == 4 else 7))
				_voice(buffer, at, step_seconds * 6.5, _hz(tone), spec.chord_gain, 2, 0.02, 2.3)
		# Lead: a pentatonic motif that sits above the pad.
		if spec.lead:
			var motif: Array = [0, 4, 7, 4, 9, 7, 4, 0]
			for i in motif.size():
				if (bar + i) % 3 == 2:
					continue
				var at := bar_start + float(i * 2) * step_seconds
				var step: int = motif[i]
				_voice(buffer, at, step_seconds * 2.6, _hz(root + step + 12), spec.lead_gain, 3, 0.008, 5.0)
		# Percussion.
		for step_index in STEPS_PER_BAR:
			var at := bar_start + float(step_index) * step_seconds
			if spec.kick.has(step_index):
				_kick(buffer, at)
			if spec.snare.has(step_index):
				_snare(buffer, at, rng)
			if step_index % int(spec.hat_every) == 0:
				_hat(buffer, at, spec.hat_gain, rng)

	_soften(buffer)
	return buffer


## Adds one note into the buffer, wrapping its tail to the start so the loop is seamless.
## Waveform: 1 triangle (bass), 2 soft pulse (pad), 3 bright pulse (lead).
func _voice(buffer: PackedFloat32Array, at: float, duration: float, hz: float, gain: float, wave: int, attack: float, decay: float) -> void:
	var total := buffer.size()
	if total == 0 or hz <= 0.0:
		return
	var start := int(at * RATE)
	var count := int(duration * RATE)
	for i in count:
		var t := float(i) / RATE
		var envelope := minf(1.0, t / maxf(attack, 0.0001)) * exp(-t * decay)
		# The envelope is zero at t = 0, so only treat silence as "finished" past the attack.
		if t > attack and envelope < 0.0005:
			break
		var phase := hz * t
		var sample := 0.0
		match wave:
			1:
				sample = absf(fposmod(phase, 1.0) * 4.0 - 2.0) - 1.0
			2:
				sample = (1.0 if fposmod(phase, 1.0) < 0.5 else -1.0) * 0.5
				sample += sin(TAU * phase) * 0.5
			_:
				var duty := 0.35
				sample = (1.0 - duty) if fposmod(phase, 1.0) < duty else -duty
				sample *= 1.5 * (0.6 + sin(TAU * 5.0 * t) * 0.05)
		var index := (start + i) % total
		buffer[index] = buffer[index] + sample * envelope * gain


func _kick(buffer: PackedFloat32Array, at: float) -> void:
	var total := buffer.size()
	var start := int(at * RATE)
	var count := int(0.16 * RATE)
	for i in count:
		var t := float(i) / RATE
		var hz := 118.0 * exp(-t * 26.0) + 42.0
		var sample := sin(TAU * hz * t) * exp(-t * 15.0) * 0.40
		var index := (start + i) % total
		buffer[index] = buffer[index] + sample


func _snare(buffer: PackedFloat32Array, at: float, rng: RandomNumberGenerator) -> void:
	var total := buffer.size()
	var start := int(at * RATE)
	var count := int(0.19 * RATE)
	for i in count:
		var t := float(i) / RATE
		var sample := rng.randf_range(-1.0, 1.0) * exp(-t * 26.0) * 0.15
		sample += sin(TAU * 210.0 * t) * exp(-t * 34.0) * 0.10
		var index := (start + i) % total
		buffer[index] = buffer[index] + sample


func _hat(buffer: PackedFloat32Array, at: float, gain: float, rng: RandomNumberGenerator) -> void:
	var total := buffer.size()
	var start := int(at * RATE)
	var count := int(0.05 * RATE)
	for i in count:
		var t := float(i) / RATE
		var sample := rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * gain
		var index := (start + i) % total
		buffer[index] = buffer[index] + sample


## One-pole lowpass to take the edge off the square waves, then a soft clip.
func _soften(buffer: PackedFloat32Array) -> void:
	var previous := 0.0
	var warm := mini(buffer.size(), 2000)
	for i in range(buffer.size() - warm, buffer.size()):
		previous = previous + (buffer[i] - previous) * 0.42
	for i in buffer.size():
		previous = previous + (buffer[i] - previous) * 0.42
		buffer[i] = previous
	var peak := 0.0
	for value in buffer:
		peak = maxf(peak, absf(value))
	if peak <= 0.0001:
		return
	var normalise := 0.95 / peak
	for i in buffer.size():
		var value := buffer[i] * normalise
		buffer[i] = value / (1.0 + absf(value) * 0.28)


func _hz(semitone: int) -> float:
	# Semitone 0 is middle C.
	return 261.63 * pow(2.0, float(semitone) / 12.0)


func _to_stream(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i in buffer.size():
		data.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = buffer.size()
	return wav
