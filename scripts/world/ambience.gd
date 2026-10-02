extends Node

## Sonido ambiente del glaciar:
## - Viento en bucle; sube con las ráfagas de `Snowfall` y con la altura.
## - Agua en bucle; se oye al estar cerca del agua o nadando.
## - Crujidos lejanos del glaciar cada cierto tiempo, al azar.

@export var wind_volume_db: float = -14.0
@export var wind_gust_range_db: float = 8.0     # cuánto suben las ráfagas
@export var wind_height_bonus_db: float = 6.0   # extra en lo alto (a 40 m)
@export var water_volume_db: float = -12.0
@export var water_near_distance: float = 7.0    # a qué distancia del agua empieza a oírse
@export var groan_interval: Vector2 = Vector2(35.0, 90.0)
@export var groan_volume_db: float = -16.0
@export var night_wind_db: float = -3.0         # la noche es un poco más tranquila

var _wind: AudioStreamPlayer = null
var _water: AudioStreamPlayer = null
var _groan: AudioStreamPlayer = null
var _player: Node3D = null
var _snow: Node = null
var _cycle: Node = null
var _water_target: float = 0.0
var _water_level: float = 0.0
var _probe_timer: float = 0.0
var _groan_timer: float = 0.0

func _ready() -> void:
	_wind = _make_player("wind_loop")
	_water = _make_player("water_loop")
	_groan = AudioStreamPlayer.new()
	add_child(_groan)
	_water.volume_db = -80.0
	_groan_timer = randf_range(groan_interval.x * 0.3, groan_interval.y * 0.5)

func _make_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream(sound)
	add_child(p)
	if p.stream:
		p.play(randf() * p.stream.get_length())
	return p

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		_snow = get_tree().root.find_child("Snowfall", true, false)
		_cycle = get_tree().get_first_node_in_group("day_night")
		return
	# Viento.
	var gust: float = _snow.get_gust() if _snow and _snow.has_method("get_gust") else 0.5
	var height := clampf(_player.global_position.y / 40.0, 0.0, 1.0)
	var night: float = _cycle.get_night_amount() if _cycle else 0.0
	var wind_db := wind_volume_db + wind_gust_range_db * (gust - 0.5) + wind_height_bonus_db * height + night_wind_db * night
	_wind.volume_db = lerpf(_wind.volume_db, wind_db, minf(delta * 2.0, 1.0))
	_wind.pitch_scale = lerpf(_wind.pitch_scale, 0.9 + gust * 0.2, minf(delta, 1.0))

	# Agua: medir cada medio segundo qué tan cerca está.
	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.5
		_water_target = _water_proximity()
	_water_level = lerpf(_water_level, _water_target, minf(delta * 1.5, 1.0))
	_water.volume_db = linear_to_db(maxf(_water_level, 0.0001)) + water_volume_db

	# Crujidos del glaciar.
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = randf_range(groan_interval.x, groan_interval.y)
		_groan.stream = Sfx.get_stream("glacier_groan")
		_groan.volume_db = groan_volume_db + randf_range(-4.0, 2.0)
		_groan.pitch_scale = randf_range(0.75, 1.1)
		_groan.play()

## 1 = nadando o pegado al agua, 0 = lejos. Rayos hacia abajo alrededor de Kael:
## si alguno no encuentra suelo por encima del agua, hay agua cerca.
func _water_proximity() -> float:
	var water := get_tree().get_first_node_in_group("water_volume")
	if water == null:
		return 0.0
	if _player.get("state") == 2:   # nadando
		return 1.0
	var surface: float = water.get_surface_y()
	if _player.global_position.y - surface > 12.0:
		return 0.0
	var space := _player.get_world_3d().direct_space_state
	var best := 0.0
	for k in 8:
		var a := TAU * k / 8.0
		for r: float in [water_near_distance * 0.4, water_near_distance]:
			var p := _player.global_position + Vector3(cos(a), 0.0, sin(a)) * r
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, Vector3(p.x, surface - 0.5, p.z))
			q.exclude = [_player.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty() or hit.position.y < surface + 0.1:
				best = maxf(best, 1.0 - r / (water_near_distance * 1.2))
	var height_fade := 1.0 - clampf((_player.global_position.y - surface - 2.0) / 10.0, 0.0, 1.0)
	return best * height_fade
