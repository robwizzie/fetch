extends Node
## Placeholder audio: short sounds synthesised at startup so the prototype has feedback
## before real assets exist. Replace by pointing [method play] names at real AudioStreams
## (drop files in res://assets/audio/ and register them in [member _streams]).

const RATE := 22050
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var enabled := true


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_streams["throw"] = _synth(func(t: float, d: float) -> float:
		return sin(TAU * (260.0 + 1100.0 * t / d) * t) * (1.0 - t / d), 0.14)
	_streams["bounce"] = _synth(func(t: float, _d: float) -> float:
		return sin(TAU * 170.0 * t) * exp(-t * 28.0), 0.14)
	_streams["catch"] = _synth(func(t: float, d: float) -> float:
		var f := 620.0 if t < 0.07 else 930.0
		return sin(TAU * f * t) * (1.0 - t / d), 0.18)
	_streams["bonk"] = _synth(func(t: float, _d: float) -> float:
		return (sin(TAU * 85.0 * t) * 0.8 + randf_range(-0.5, 0.5)) * exp(-t * 10.0), 0.35)
	_streams["dash"] = _synth(func(t: float, d: float) -> float:
		return randf_range(-1.0, 1.0) * (1.0 - t / d) * 0.5, 0.09)
	_streams["pickup"] = _synth(func(t: float, d: float) -> float:
		return sin(TAU * (440.0 + 300.0 * t / d) * t) * (1.0 - t / d), 0.08)
	_streams["whistle"] = _synth(func(t: float, d: float) -> float:
		return sin(TAU * (1400.0 + 500.0 * sin(t * 40.0)) * t) * (1.0 - t / d) * 0.6, 0.35)
	_streams["tick"] = _synth(func(t: float, d: float) -> float:
		return sin(TAU * 520.0 * t) * (1.0 - t / d), 0.07)
	_streams["fanfare"] = _synth(func(t: float, d: float) -> float:
		var step := int(t / 0.11)
		var f: float = [523.0, 659.0, 784.0, 1046.0][mini(step, 3)]
		return sin(TAU * f * t) * (1.0 - t / d) * 0.7, 0.5)
	_streams["ui"] = _synth(func(t: float, d: float) -> float:
		return sin(TAU * 700.0 * t) * (1.0 - t / d) * 0.4, 0.05)


func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(sound_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound_name]
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return


func _synth(generator: Callable, duration: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s: float = clampf(generator.call(t, duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0 * 0.5))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
