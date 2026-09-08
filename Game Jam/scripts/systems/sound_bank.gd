extends Node
## Every sound effect is synthesised once at startup, so the project ships no
## audio assets. One shared player means a new cue always replaces the last one.

const MIX_RATE: int = 22050
const VOLUME_DB: float = -20.0
const SHORT_CUE: float = 0.07
const LONG_CUE: float = 0.2
const CUES: PackedStringArray = [
	"jump", "double_jump", "wall_jump", "land", "dash", "strike",
	"bounce", "break", "anchor", "freeze", "hit", "goal",
	"portal_open", "portal_whoosh", "portal_arrive",
]

var sfx: AudioStreamPlayer
var sounds: Dictionary = {}


func _ready() -> void:
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = VOLUME_DB
	add_child(sfx)
	for cue in CUES:
		sounds[cue] = _render(cue)


func play(cue: String) -> void:
	if not sounds.has(cue):
		return
	sfx.stream = sounds[cue]
	sfx.play()


## Frequency sweep per cue, shaped by a quadratic decay envelope.
func _frequency(cue: String, t: float) -> float:
	match cue:
		"jump": return 420.0 + t * 4200.0
		"double_jump": return 750.0 + t * 6000.0
		"wall_jump": return 580.0 + t * 3800.0
		"land": return 160.0 - t * 1100.0
		"dash": return 900.0 - t * 8000.0
		"strike": return 320.0 - t * 2200.0
		"bounce": return 260.0 + t * 8500.0
		"break": return 240.0 + sin(t * 2300.0) * 150.0
		"anchor": return 1100.0 + t * 3500.0
		"freeze": return 1350.0 - t * 3000.0
		"hit": return 90.0 + sin(t * 1700.0) * 35.0
		"goal": return 660.0 if t < 0.08 else 990.0
	return 640.0


func _render(cue: String) -> AudioStreamWAV:
	var duration: float = LONG_CUE if cue == "goal" else SHORT_CUE
	if cue.begins_with("portal_"):
		return _render_portal(cue)
	var count: int = int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var envelope: float = pow(1.0 - float(i) / float(count), 2.0)
		var sample: int = int(sin(TAU * _frequency(cue, t) * t) * envelope * 12000)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream


## Original soft sine/noise sweeps; share the existing Master bus and -20 dB gain.
func _render_portal(cue: String) -> AudioStreamWAV:
	var duration: float = 0.4 if cue == "portal_open" else (0.8 if cue == "portal_whoosh" else 0.5)
	var count: int = int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	var noise: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(count):
		var t: float = float(i) / MIX_RATE
		var p: float = t / duration
		var frequency: float = lerpf(120.0, 420.0, p) if cue == "portal_open" else (lerpf(180.0, 1200.0, p * p) if cue == "portal_whoosh" else lerpf(880.0, 440.0, p))
		phase += TAU * frequency / MIX_RATE
		noise = lerpf(noise, rng.randf_range(-1, 1), 0.15)
		var envelope: float = smoothstep(0.0, 0.08, p) * pow(1.0 - p, 0.75)
		var signal_value: float = sin(phase) * 0.48 + sin(phase * 1.5) * 0.22 + noise * (0.6 if cue == "portal_whoosh" else 0.12)
		bytes.encode_s16(i * 2, int(clampf(signal_value * envelope, -0.9, 0.9) * 16000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream
