extends MeshInstance3D

## Da movimiento al agua: una textura de ruido como mapa de normales que se
## desplaza despacio. Se aplica sobre el material translúcido del plano.

@export var tile_size: float = 9.0         # metros por repetición de la textura
@export var scroll_speed: Vector2 = Vector2(0.004, 0.0025)
@export var normal_strength: float = 0.45

var _mat: StandardMaterial3D = null

func _ready() -> void:
	_mat = get_surface_override_material(0) as StandardMaterial3D
	if _mat == null or mesh == null:
		return
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	tex.noise = noise
	_mat.normal_enabled = true
	_mat.normal_texture = tex
	_mat.normal_scale = normal_strength
	var plane_size: float = (mesh as PlaneMesh).size.x
	var tiles := plane_size / tile_size
	_mat.uv1_scale = Vector3(tiles, tiles, 1.0)

func _process(delta: float) -> void:
	if _mat:
		_mat.uv1_offset += Vector3(scroll_speed.x, scroll_speed.y, 0.0) * delta * 10.0
