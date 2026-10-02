extends GPUParticles3D

## Nieve que cae alrededor del jugador, empujada por un viento que cambia
## lentamente (ráfagas). Las partículas viven en el mundo, no se mueven con
## el jugador; solo el emisor lo sigue.

@export var area: float = 45.0              # medio ancho de la zona de nieve (m)
@export var emit_height: float = 14.0       # altura del emisor sobre el jugador
@export var flake_size: float = 0.18
@export var wind_direction: Vector2 = Vector2(1.0, 0.35)
@export var wind_strength: float = 1.2      # empuje constante del viento
@export var gust_strength: float = 1.6      # cuánto varían las ráfagas
@export var gust_speed: float = 0.15        # qué tan rápido cambian

var _mat := ParticleProcessMaterial.new()
var _noise := FastNoiseLite.new()
var _player: Node3D = null
var _gust01: float = 0.5   # ráfaga actual de 0 (calma) a 1 (fuerte); la usa el sonido del viento

func _ready() -> void:
	top_level = true
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = 1000
	lifetime = 9.0
	visibility_aabb = AABB(Vector3(-area, -30.0, -area), Vector3(area * 2.0, 40.0, area * 2.0))

	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_mat.emission_box_extents = Vector3(area, 1.0, area)
	_mat.direction = Vector3(0, -1, 0)
	_mat.spread = 10.0
	_mat.initial_velocity_min = 1.0
	_mat.initial_velocity_max = 2.2
	_mat.gravity = Vector3(0, -0.4, 0)
	_mat.scale_min = 0.4
	_mat.scale_max = 1.8
	# Copos que giran y se mecen un poco al caer.
	_mat.turbulence_enabled = true
	_mat.turbulence_noise_strength = 0.6
	_mat.turbulence_noise_scale = 6.0
	_mat.turbulence_influence_min = 0.05
	_mat.turbulence_influence_max = 0.15
	process_material = _mat

	var quad := QuadMesh.new()
	quad.size = Vector2(flake_size, flake_size)
	var flake := StandardMaterial3D.new()
	flake.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake.albedo_color = Color(1, 1, 1, 0.9)
	flake.albedo_texture = _soft_dot()
	flake.disable_receive_shadows = true
	quad.material = flake
	draw_pass_1 = quad

	_noise.frequency = 1.0
	_player = get_tree().get_first_node_in_group("player") as Node3D

## Copo redondo y suave (degradado radial) en vez de un cuadrado.
func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	global_position = _player.global_position + Vector3(0, emit_height, 0)

	# Ráfagas: el empuje del viento oscila con ruido lento.
	var t := Time.get_ticks_msec() * 0.001 * gust_speed
	var gust_noise := _noise.get_noise_1d(t * 10.0)
	_gust01 = clampf(gust_noise * 0.5 + 0.5, 0.0, 1.0)
	var gust := 1.0 + gust_strength * gust_noise
	var dir := wind_direction.normalized()
	var push := maxf(wind_strength * gust, 0.0)
	_mat.gravity = Vector3(dir.x * push, -0.4, dir.y * push)

func get_gust() -> float:
	return _gust01
