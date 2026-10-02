extends MeshInstance3D

## Anillo de glaciares lejanos que rodea el mapa: esconde el borde del mundo
## y da escala. Frentes de hielo que salen del mar y suben hacia montañas
## nevadas. Solo visual (sin colisión); la niebla los desvanece a lo lejos.

@export var inner_radius: float = 230.0
@export var outer_radius: float = 2200.0
@export var sea_level: float = -1.5
@export var front_height: float = 30.0     # altura del frente de hielo junto al mar
@export var peak_height: float = 380.0     # altura máxima hacia el fondo
@export var angular_segments: int = 220
@export var radial_segments: int = 32
@export var noise_seed: int = 11

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _build_mesh()

func _build_mesh() -> ArrayMesh:
	var ridged := FastNoiseLite.new()
	ridged.seed = noise_seed
	ridged.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.fractal_octaves = 4
	ridged.frequency = 0.0017
	var detail := FastNoiseLite.new()
	detail.seed = noise_seed + 5
	detail.frequency = 0.012

	var rings: Array[PackedVector3Array] = []
	var colors: Array[PackedColorArray] = []
	for ri in radial_segments + 1:
		var t := float(ri) / float(radial_segments)
		var radius := inner_radius + (outer_radius - inner_radius) * pow(t, 1.7)
		var verts := PackedVector3Array()
		var cols := PackedColorArray()
		for ai in angular_segments:
			var ang := TAU * float(ai) / float(angular_segments)
			var x := cos(ang) * radius
			var z := sin(ang) * radius
			var r := clampf(ridged.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			var rise := smoothstep(0.0, 0.85, t)
			var height := lerpf(front_height, peak_height, rise) * (0.3 + 0.7 * pow(r, 1.2))
			height += detail.get_noise_2d(x, z) * 10.0 * (0.4 + rise)
			if ri == 0:
				height = maxf(height, 18.0)
			verts.append(Vector3(x, sea_level + height, z))
			var snow := clampf(height / peak_height * 1.8, 0.0, 1.0)
			var ice := Color(0.42, 0.68, 0.92)
			var white := Color(0.84, 0.9, 0.97)
			var shade := 0.9 + detail.get_noise_2d(x * 2.0, z * 2.0) * 0.1
			cols.append(ice.lerp(white, snow) * shade)
		rings.append(verts)
		colors.append(cols)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	st.set_material(mat)
	for ri in radial_segments:
		for ai in angular_segments:
			var an := (ai + 1) % angular_segments
			var p00 := rings[ri][ai]
			var p01 := rings[ri][an]
			var p10 := rings[ri + 1][ai]
			var p11 := rings[ri + 1][an]
			var c00 := colors[ri][ai]
			var c01 := colors[ri][an]
			var c10 := colors[ri + 1][ai]
			var c11 := colors[ri + 1][an]
			# Sentido horario visto desde arriba (cara frontal en Godot): radio crece hacia afuera.
			for tri in [[p00, c00, p10, c10, p01, c01], [p01, c01, p10, c10, p11, c11]]:
				for k in 3:
					st.set_color(tri[k * 2 + 1])
					st.add_vertex(tri[k * 2])
	st.generate_normals()
	return st.commit()
