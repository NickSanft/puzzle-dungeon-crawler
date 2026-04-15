extends Node

const SAMPLE_RATE := 22050

var _player: AudioStreamPlayer
var _cache: Dictionary = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func play_click() -> void:
	_play(_tone("click", 440.0, 0.04, 0.3, "square"))

func play_mark() -> void:
	_play(_tone("mark", 220.0, 0.05, 0.3, "square"))

func play_solve() -> void:
	_play(_chord("solve", [523.25, 659.25, 783.99], 0.4, 0.35))

func play_damage() -> void:
	_play(_tone("damage", 140.0, 0.18, 0.5, "saw"))

func play_boss_win() -> void:
	_play(_chord("boss", [392.0, 523.25, 659.25, 783.99], 0.7, 0.4))

func _play(stream: AudioStreamWAV) -> void:
	_player.stream = stream
	_player.play()

func _tone(key: String, freq: float, dur: float, volume: float, shape: String = "sine") -> AudioStreamWAV:
	var cache_key := "%s_%s_%.2f_%.2f_%.2f" % [key, shape, freq, dur, volume]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var n_samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	for i in n_samples:
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = _envelope(t, dur)
		var sample: float = _waveform(shape, freq, t) * envelope * volume
		var v: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_cache[cache_key] = stream
	return stream

func _chord(key: String, freqs: Array, dur: float, volume: float) -> AudioStreamWAV:
	var cache_key := "chord_%s_%.2f_%.2f" % [key, dur, volume]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var n_samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	for i in n_samples:
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = _envelope(t, dur)
		var acc: float = 0.0
		for f in freqs:
			acc += sin(TAU * float(f) * t)
		acc /= float(freqs.size())
		var v: int = clampi(int(acc * envelope * volume * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_cache[cache_key] = stream
	return stream

func _envelope(t: float, dur: float) -> float:
	var attack: float = 0.008
	var release: float = min(0.08, dur * 0.5)
	if t < attack:
		return t / attack
	if t > dur - release:
		return max(0.0, (dur - t) / release)
	return 1.0

func _waveform(shape: String, freq: float, t: float) -> float:
	var phase: float = fmod(freq * t, 1.0)
	match shape:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"saw":
			return 2.0 * phase - 1.0
		_:
			return sin(TAU * freq * t)
