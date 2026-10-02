extends MeshInstance3D

## Prepara el shader del agua (assets/shaders/water.gdshader): genera una
## textura de ruido como mapa de normales que el shader desplaza en dos
## direcciones para las ondas. El color por profundidad y la espuma de orilla
## se calculan en el shader.

@export var noise_frequency: float = 0.02
@export var bump_strength: float = 6.0

func _ready() -> void:
	var mat := get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = bump_strength
	var noise := FastNoiseLite.new()
	noise.frequency = noise_frequency
	tex.noise = noise
	mat.set_shader_parameter("normal_map", tex)
