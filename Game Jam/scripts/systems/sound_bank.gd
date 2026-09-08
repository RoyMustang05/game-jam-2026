extends Node
## Every sound effect is synthesised once at startup, so the project ships no
## audio assets. One shared player means a new cue always replaces the last one.

const MIX_RATE: int = 22050
const VOLUME_DB: float = -20.0
const MUSIC_VOLUME_DB: PackedFloat32Array = [-14.0, -14.0, -14.0, -21.0]
const SHORT_CUE: float = 0.07
const LONG_CUE: float = 0.2
const CUES: PackedStringArray = [
	"jump", "double_jump", "wall_jump", "land", "dash", "strike",
	"bounce", "break", "anchor", "freeze", "hit", "goal",
]
const MUSIC: Array[AudioStream] = [
	preload("res://music/level 1.mp3"),
	preload("res://music/level 2.mp3"),
	preload("res://music/level 3.mp3"),
	preload("res://music/level 4.mp3"),
]

var sfx: AudioStreamPlayer
var music: AudioStreamPlayer
var sounds: Dictionary = {}


func _ready() -> void:
	sfx = AudioStreamPlayer.new()
	sfx.volume_db = VOLUME_DB
	add_child(sfx)
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_VOLUME_DB[0]
	music.finished.connect(_restart_music)
	add_child(music)
	for cue in CUES:
		sounds[cue] = _render(cue)


func play(cue: String) -> void:
	if not sounds.has(cue):
		return
	sfx.stream = sounds[cue]
	sfx.play()


func play_music(level_index: int) -> void:
	if level_index < 0 or level_index >= MUSIC.size():
		music.stop()
		music.stream = null
		return
	var next_track := MUSIC[level_index]
	music.volume_db = MUSIC_VOLUME_DB[level_index]
	if music.stream == next_track and music.playing:
		return
	music.stop()
	music.stream = next_track
	music.play()


func _restart_music() -> void:
	if music.stream != null:
		music.play()


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
