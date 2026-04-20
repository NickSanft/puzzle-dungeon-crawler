extends Node

const SAMPLE_RATE := 22050

# A diatonic scale (C major) the click/mark tones snap onto, indexed by
# "semitone offset from C4". Using this rather than arbitrary pitches turns
# a row of cell clicks into a short, listenable melody.
const SCALE_RATIOS := [1.0, 9.0/8.0, 5.0/4.0, 4.0/3.0, 3.0/2.0, 5.0/3.0, 15.0/8.0, 2.0]
const CLICK_BASE_FREQ := 392.0  # G4
const MARK_BASE_FREQ := 220.0  # A3

var _player: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _cache: Dictionary = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_restore_volumes()

func _restore_volumes() -> void:
	var master: float = float(SaveSystem.setting("vol_master", 1.0))
	var sfx: float = float(SaveSystem.setting("vol_sfx", 1.0))
	var ambient: float = float(SaveSystem.setting("vol_ambient", 0.5))
	AudioServer.set_bus_volume_db(0, _vol_to_db(master))
	_player.volume_db = _vol_to_db(sfx)
	_ambient.volume_db = _vol_to_db(ambient)

static func _vol_to_db(val: float) -> float:
	if val <= 0.001:
		return -80.0
	return 20.0 * log(val) / log(10.0)

# --- Click / mark: pitch varies by provided "index" so successive clicks form
# a short motif instead of monotone blips. Callers can just pass 0 if they
# don't want to bother; default falls back to the base pitch.
func play_click(index: int = 0) -> void:
	var ratio: float = SCALE_RATIOS[index % SCALE_RATIOS.size()]
	var freq: float = CLICK_BASE_FREQ * ratio
	_play(_tone("click", freq, 0.04, 0.28, "square"))

func play_mark(index: int = 0) -> void:
	var ratio: float = SCALE_RATIOS[index % SCALE_RATIOS.size()]
	var freq: float = MARK_BASE_FREQ * ratio
	_play(_tone("mark", freq, 0.05, 0.28, "square"))

func play_solve() -> void:
	# Chord + short ascending arpeggio overlaid.
	_play(_solve_stream())

func play_damage() -> void:
	_play(_damage_stream())

func play_boss_win() -> void:
	_play(_chord("boss", [392.0, 523.25, 659.25, 783.99], 0.7, 0.4))

func start_ambient(intensity: float = 0.5) -> void:
	if _ambient == null:
		return
	var key := "ambient_%.2f" % intensity
	if not _cache.has(key):
		_cache[key] = _ambient_stream(intensity)
	var stream: AudioStreamWAV = _cache[key]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	@warning_ignore("integer_division")
	stream.loop_end = (stream.data.size() / 2) - 1
	_ambient.stream = stream
	_ambient.volume_db = lerp(-24.0, -12.0, intensity)
	if not _ambient.playing:
		_ambient.play()

func stop_ambient() -> void:
	if _ambient != null and _ambient.playing:
		_ambient.stop()

# --- Synthesis ----------------------------------------------------------

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
	var stream := _make_stream(data)
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
	var stream := _make_stream(data)
	_cache[cache_key] = stream
	return stream

func _solve_stream() -> AudioStreamWAV:
	var key := "solve_v2"
	if _cache.has(key):
		return _cache[key]
	var dur: float = 0.55
	var n_samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	# Base chord (C E G).
	var base_freqs: Array = [523.25, 659.25, 783.99]
	# Ascending arpeggio layered on top, starts later.
	var arp: Array = [
		{"f": 659.25, "start": 0.00, "dur": 0.10},
		{"f": 783.99, "start": 0.08, "dur": 0.10},
		{"f": 987.77, "start": 0.16, "dur": 0.12},
		{"f": 1174.66, "start": 0.26, "dur": 0.14},
	]
	for i in n_samples:
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = _envelope(t, dur)
		var acc: float = 0.0
		for f in base_freqs:
			acc += sin(TAU * float(f) * t)
		acc /= float(base_freqs.size())
		var arp_acc: float = 0.0
		for note in arp:
			var nt: float = t - float(note.start)
			var nd: float = float(note.dur)
			if nt >= 0.0 and nt <= nd:
				var nenv: float = _envelope(nt, nd)
				arp_acc += sin(TAU * float(note.f) * nt) * nenv * 0.6
		var sample: float = (acc * envelope * 0.35) + (arp_acc * 0.35)
		var v: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var stream := _make_stream(data)
	_cache[key] = stream
	return stream

func _damage_stream() -> AudioStreamWAV:
	var key := "damage_v2"
	if _cache.has(key):
		return _cache[key]
	var dur: float = 0.22
	var n_samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	# Saw thud + low sine body for weight.
	var saw_freq: float = 140.0
	var body_freq: float = 70.0
	for i in n_samples:
		var t: float = float(i) / SAMPLE_RATE
		var envelope: float = _envelope(t, dur)
		var saw_v: float = _waveform("saw", saw_freq, t) * 0.55
		var body: float = sin(TAU * body_freq * t) * 0.45
		var sample: float = (saw_v + body) * envelope * 0.55
		var v: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	var stream := _make_stream(data)
	_cache[key] = stream
	return stream

func _ambient_stream(intensity: float) -> AudioStreamWAV:
	# Low drone built from detuned sines + slow LFO breathing.
	# 2-second looping buffer so memory stays small.
	var dur: float = 2.0
	var n_samples: int = int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(n_samples * 2)
	var base: float = 55.0
	var freqs: Array = [
		base,
		base * 1.005,  # very slight detune
		base * 2.0,
		base * 3.0,
	]
	for i in n_samples:
		var t: float = float(i) / SAMPLE_RATE
		var lfo: float = 0.85 + 0.15 * sin(TAU * 0.25 * t)
		var acc: float = 0.0
		for f in freqs:
			acc += sin(TAU * float(f) * t)
		acc /= float(freqs.size())
		var sample: float = acc * lfo * 0.4 * intensity
		var v: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xff
		data[i * 2 + 1] = (v >> 8) & 0xff
	return _make_stream(data)

func _make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
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
