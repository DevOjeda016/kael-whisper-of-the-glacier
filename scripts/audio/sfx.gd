extends Node

## Efectos de sonido (autoload `Sfx`). Los .wav provisionales los genera
## tools/gen_sfx.py; para usar audio real basta con reemplazar el archivo.
##   Sfx.play("beacon_chime")                      # sin posición (2D)
##   Sfx.play_at("ice_create", posicion)           # en el mundo (3D)
## Un nombre con variantes ("step_snow") elige una al azar (step_snow_1..4).

const DIR := "res://assets/audio/sfx/"
const VARIANTS := {"step_snow": 4}
const LOOPS := ["wind_loop", "water_loop"]

@export var pool_size: int = 12

var _cache: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in pool_size:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 60.0
		add_child(p3)
		_pool_3d.append(p3)
	for i in 4:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_pool_2d.append(p2)

## Devuelve el stream (con caché). Los de LOOPS quedan en bucle.
func get_stream(sound: String) -> AudioStream:
	var file := sound
	if VARIANTS.has(sound):
		file = "%s_%d" % [sound, randi_range(1, VARIANTS[sound])]
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Sfx: no existe " + path)
		_cache[file] = null
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV and file in LOOPS:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_cache[file] = stream
	return stream

func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08, base_pitch: float = 1.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = base_pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
