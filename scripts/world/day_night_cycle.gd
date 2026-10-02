extends Node

## Ciclo de día y noche estilo Breath of the Wild: un día de juego dura
## `day_length_minutes` minutos reales (BotW: 24). Mueve el sol y la luna,
## y cambia los colores del cielo, la niebla y la luz ambiente según la hora.
## De noche salen estrellas y aurora boreal (en el shader del cielo).
##
## Otros nodos lo encuentran por el grupo "day_night": `get_hour()`,
## `is_night()`, `rest_until(hour)` (descansar en un tótem).

signal hour_changed(hour: int)

@export var day_length_minutes: float = 24.0
@export var start_hour: float = 9.0
@export var paused: bool = false
@export var sun_path: NodePath = ^"../DirectionalLight3D"
@export var moon_path: NodePath = ^"../Moon"
@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var max_sun_elevation_deg: float = 58.0   # altura del sol a mediodía
@export var path_tilt: float = 0.65                # cuánto se inclina la trayectoria hacia el sur (+Z)
@export var moon_max_energy: float = 0.45
@export var night_exposure_boost: float = 0.25     # sube un poco la exposición de noche para que se vea (como BotW)

var hour: float = 9.0

var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _env: Environment = null
var _sky_mat: ShaderMaterial = null
var _base_exposure: float = 1.0
var _last_whole_hour: int = -1
var _resting: bool = false

# Paleta por hora: se interpola linealmente entre claves (y da la vuelta a las 24).
# night: 0 = día, 1 = noche plena (estrellas, aurora, luna).
const KEYS := [
	{"h": 0.0, "top": Color(0.02, 0.04, 0.10), "hor": Color(0.07, 0.11, 0.20), "ground": Color(0.04, 0.06, 0.10), "sun": Color(1.0, 0.5, 0.3), "sun_e": 0.0, "amb": Color(0.35, 0.45, 0.75), "amb_e": 0.45, "fog": Color(0.08, 0.12, 0.22), "cl": Color(0.22, 0.27, 0.38), "cs": Color(0.06, 0.08, 0.14), "night": 1.0},
	{"h": 4.5, "top": Color(0.03, 0.05, 0.12), "hor": Color(0.10, 0.13, 0.24), "ground": Color(0.05, 0.07, 0.12), "sun": Color(1.0, 0.5, 0.3), "sun_e": 0.0, "amb": Color(0.35, 0.45, 0.75), "amb_e": 0.45, "fog": Color(0.10, 0.13, 0.24), "cl": Color(0.22, 0.27, 0.38), "cs": Color(0.07, 0.09, 0.15), "night": 1.0},
	{"h": 5.75, "top": Color(0.16, 0.22, 0.42), "hor": Color(0.85, 0.55, 0.45), "ground": Color(0.25, 0.22, 0.28), "sun": Color(1.0, 0.55, 0.35), "sun_e": 0.25, "amb": Color(0.6, 0.55, 0.75), "amb_e": 0.5, "fog": Color(0.6, 0.5, 0.55), "cl": Color(1.0, 0.7, 0.6), "cs": Color(0.35, 0.3, 0.45), "night": 0.35},
	{"h": 7.0, "top": Color(0.22, 0.40, 0.68), "hor": Color(0.95, 0.80, 0.68), "ground": Color(0.32, 0.38, 0.46), "sun": Color(1.0, 0.75, 0.55), "sun_e": 1.0, "amb": Color(0.75, 0.8, 0.95), "amb_e": 0.65, "fog": Color(0.82, 0.80, 0.82), "cl": Color(1.0, 0.9, 0.82), "cs": Color(0.58, 0.6, 0.7), "night": 0.0},
	{"h": 10.0, "top": Color(0.24, 0.45, 0.72), "hor": Color(0.78, 0.86, 0.93), "ground": Color(0.36, 0.44, 0.52), "sun": Color(1.0, 0.9, 0.78), "sun_e": 1.25, "amb": Color(0.75, 0.85, 1.0), "amb_e": 0.75, "fog": Color(0.74, 0.82, 0.9), "cl": Color(0.98, 0.97, 0.95), "cs": Color(0.62, 0.69, 0.78), "night": 0.0},
	{"h": 15.0, "top": Color(0.24, 0.45, 0.72), "hor": Color(0.78, 0.86, 0.93), "ground": Color(0.36, 0.44, 0.52), "sun": Color(1.0, 0.9, 0.78), "sun_e": 1.25, "amb": Color(0.75, 0.85, 1.0), "amb_e": 0.75, "fog": Color(0.74, 0.82, 0.9), "cl": Color(0.98, 0.97, 0.95), "cs": Color(0.62, 0.69, 0.78), "night": 0.0},
	{"h": 17.5, "top": Color(0.22, 0.36, 0.62), "hor": Color(0.98, 0.72, 0.52), "ground": Color(0.34, 0.32, 0.38), "sun": Color(1.0, 0.68, 0.42), "sun_e": 1.1, "amb": Color(0.85, 0.75, 0.8), "amb_e": 0.65, "fog": Color(0.88, 0.72, 0.65), "cl": Color(1.0, 0.82, 0.65), "cs": Color(0.55, 0.45, 0.55), "night": 0.0},
	{"h": 18.75, "top": Color(0.14, 0.18, 0.40), "hor": Color(0.95, 0.45, 0.32), "ground": Color(0.22, 0.18, 0.24), "sun": Color(1.0, 0.45, 0.25), "sun_e": 0.35, "amb": Color(0.6, 0.5, 0.7), "amb_e": 0.5, "fog": Color(0.55, 0.38, 0.42), "cl": Color(1.0, 0.55, 0.45), "cs": Color(0.3, 0.22, 0.35), "night": 0.3},
	{"h": 20.0, "top": Color(0.03, 0.05, 0.13), "hor": Color(0.12, 0.14, 0.28), "ground": Color(0.05, 0.07, 0.12), "sun": Color(1.0, 0.45, 0.25), "sun_e": 0.0, "amb": Color(0.35, 0.45, 0.75), "amb_e": 0.45, "fog": Color(0.10, 0.13, 0.24), "cl": Color(0.22, 0.27, 0.38), "cs": Color(0.07, 0.09, 0.15), "night": 1.0},
]

func _ready() -> void:
	add_to_group("day_night")
	hour = fposmod(start_hour, 24.0)
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_moon = get_node_or_null(moon_path) as DirectionalLight3D
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_base_exposure = _env.tonemap_exposure
		if _env.sky:
			_sky_mat = _env.sky.sky_material as ShaderMaterial
	_apply()

func _process(delta: float) -> void:
	if paused or _resting or day_length_minutes <= 0.0:
		return
	advance(delta * 24.0 / (day_length_minutes * 60.0))

## Avanza el reloj `hours` horas de juego.
func advance(hours: float) -> void:
	hour = fposmod(hour + hours, 24.0)
	_apply()

func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply()

func get_hour() -> float:
	return hour

func get_night_amount() -> float:
	return _sample("night")

func is_night() -> bool:
	return hour >= 19.5 or hour < 5.5

## Descansar hasta la hora `target` (como en las fogatas de BotW): fundido a
## negro, el tiempo corre rápido y vuelve la imagen.
func rest_until(target: float) -> void:
	if _resting:
		return
	_resting = true
	var fade := get_tree().get_first_node_in_group("screen_fade")
	if fade:
		fade.fade_to(1.0, 0.6)
		await get_tree().create_timer(0.7).timeout
	set_hour(target)
	await get_tree().create_timer(0.6).timeout
	if fade:
		fade.fade_to(0.0, 0.8)
	_resting = false

func is_resting() -> bool:
	return _resting

func _apply() -> void:
	# Trayectoria: sale por el este (+X) a las 6, cenit a las 12, se pone por el oeste a las 18.
	var a := (hour - 6.0) / 12.0 * PI
	var sun_dir := Vector3(cos(a), sin(a) * tan(deg_to_rad(max_sun_elevation_deg)) * 0.7, path_tilt).normalized()
	var moon_dir := Vector3(-cos(a), -sin(a) * 0.9, path_tilt * 0.8).normalized()
	var night := _sample("night")

	if _sun:
		_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
		var above := smoothstep(-0.02, 0.12, sun_dir.y)
		_sun.light_energy = _sample("sun_e") * above
		_sun.light_color = _sample_color("sun")
		_sun.visible = _sun.light_energy > 0.01
	if _moon:
		_moon.look_at_from_position(Vector3.ZERO, -moon_dir, Vector3.UP if absf(moon_dir.y) < 0.99 else Vector3.FORWARD)
		var moon_above := smoothstep(-0.02, 0.15, moon_dir.y)
		_moon.light_energy = moon_max_energy * night * moon_above
		_moon.visible = _moon.light_energy > 0.01
		# Una sola luz con sombras a la vez: la que domina.
		_moon.shadow_enabled = _sun == null or not _sun.visible
	if _env:
		_env.ambient_light_color = _sample_color("amb")
		_env.ambient_light_energy = _sample("amb_e")
		_env.fog_light_color = _sample_color("fog")
		_env.tonemap_exposure = _base_exposure + night_exposure_boost * night
	if _sky_mat:
		_sky_mat.set_shader_parameter("top_color", _sample_color("top"))
		_sky_mat.set_shader_parameter("horizon_color", _sample_color("hor"))
		_sky_mat.set_shader_parameter("ground_color", _sample_color("ground"))
		_sky_mat.set_shader_parameter("sun_color", _sample_color("sun"))
		_sky_mat.set_shader_parameter("cloud_light", _sample_color("cl"))
		_sky_mat.set_shader_parameter("cloud_shadow", _sample_color("cs"))
		_sky_mat.set_shader_parameter("sun_dir", sun_dir)
		_sky_mat.set_shader_parameter("moon_dir", moon_dir)
		_sky_mat.set_shader_parameter("night", night)
	var whole := int(hour)
	if whole != _last_whole_hour:
		_last_whole_hour = whole
		hour_changed.emit(whole)

## Busca las dos claves que rodean la hora actual y cuánto se avanzó entre ellas.
func _bracket() -> Array:
	var n := KEYS.size()
	for i in n:
		var k0: Dictionary = KEYS[i]
		var k1: Dictionary = KEYS[(i + 1) % n]
		var h0: float = k0.h
		var h1: float = k1.h if i + 1 < n else k1.h + 24.0
		var h := hour if hour >= h0 else hour + 24.0
		if h >= h0 and h < h1:
			return [k0, k1, (h - h0) / (h1 - h0)]
	return [KEYS[0], KEYS[0], 0.0]

func _sample(key: String) -> float:
	var b := _bracket()
	return lerpf(b[0][key], b[1][key], smoothstep(0.0, 1.0, b[2]))

func _sample_color(key: String) -> Color:
	var b := _bracket()
	return (b[0][key] as Color).lerp(b[1][key], smoothstep(0.0, 1.0, b[2]))
