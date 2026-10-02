extends StaticBody3D

## Formación de hielo procedural: una caja cuyas paredes se ondulan en
## horizontal (siguen siendo verticales, así que se pueden trepar) y cuya
## cima se abulta suavemente. Genera su propia malla y colisión al iniciar.
##
## El ruido se evalúa en coordenadas de MUNDO, así que dos formaciones
## vecinas con la misma semilla ondulan igual y sus bordes coinciden.
## Para reemplazarla por un modelo de Meshy: borra el nodo y pon el modelo.

@export var size: Vector3 = Vector3(10, 10, 10)
@export var material: Material
@export var cell: float = 2.0            # tamaño de celda de la malla (m)
@export var wobble: float = 0.7          # ondulación horizontal de las paredes (m)
@export var top_bump: float = 0.25       # relieve de la cima (m)
@export var strata: float = 0.25         # variación de la ondulación con la altura
@export var noise_seed: int = 7
@export var skip_bottom: bool = true
# Formas orgánicas (solo si wobble > 0; las formaciones lisas, como el pilar, quedan rectas):
@export var corner_radius: float = -1.0   # radio de las esquinas vistas desde arriba; -1 = automático
@export var max_corner_radius: float = 5.0
@export var snow_lip: float = 0.3         # cuánto sobresale el borde de nieve de la cima (m)
@export var outline_wobble: float = 1.6   # ondulación amplia del contorno (rompe bordes rectos largos)
# Carámbanos colgando del borde superior (solo si la cima está sobre el agua):
@export var icicle_density: float = 0.45  # carámbanos por metro de borde
@export var icicle_length: Vector2 = Vector2(0.4, 1.6)
@export var icicle_min_top_y: float = 1.0 # no poner carámbanos en losas a nivel del suelo

var _noise_a := FastNoiseLite.new()
var _noise_b := FastNoiseLite.new()
var _noise_c := FastNoiseLite.new()
var _noise_d := FastNoiseLite.new()

func _ready() -> void:
	for n in [_noise_a, _noise_b, _noise_c]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_a.seed = noise_seed
	_noise_a.frequency = 0.045
	_noise_b.seed = noise_seed + 101
	_noise_b.frequency = 0.045
	_noise_c.seed = noise_seed + 202
	_noise_c.frequency = 0.07
	_noise_d.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_d.seed = noise_seed + 303
	_noise_d.frequency = 0.018
	_build()

func _organic() -> bool:
	return wobble > 0.0

func _corner_r() -> float:
	if not _organic():
		return 0.0
	if corner_radius >= 0.0:
		return corner_radius
	return minf(max_corner_radius, 0.18 * minf(size.x, size.z))

## Redondea las esquinas vistas desde arriba y saca un poco el borde de la cima.
func _round_plan(p: Vector3) -> Vector3:
	var h := size * 0.5
	var out := p
	var r := _corner_r()
	if r > 0.0:
		var cx := h.x - r
		var cz := h.z - r
		var d := Vector2(absf(p.x) - cx, absf(p.z) - cz)
		if d.x > 0.0 and d.y > 0.0 and d.length() > r:
			d = d.normalized() * r
			out.x = signf(p.x) * (cx + d.x)
			out.z = signf(p.z) * (cz + d.y)
	if _organic() and snow_lip > 0.0 and p.y >= h.y - 0.001:
		var edge := absf(p.x) >= h.x - 0.001 or absf(p.z) >= h.z - 0.001
		if edge:
			var outward := Vector2(out.x, out.z)
			var inner := Vector2(clampf(out.x, -h.x + r, h.x - r), clampf(out.z, -h.z + r, h.z - r))
			var dir := (outward - inner).normalized() if outward.distance_to(inner) > 0.001 else Vector2(signf(p.x), 0.0)
			out.x += dir.x * snow_lip
			out.z += dir.y * snow_lip
	return out

func _shape(p_in: Vector3) -> Vector3:
	var p := _round_plan(p_in)
	var out := p
	var o := global_position
	if _organic() and outline_wobble > 0.0:
		# Igual en toda la altura (las paredes siguen verticales) y misma amplitud en
		# todas las formaciones: como el ruido es de mundo, las caras que se tocan
		# se desplazan igual y no se abren grietas entre ellas.
		out.x += _noise_d.get_noise_2d(p.x + o.x, p.z + o.z) * outline_wobble
		out.z += _noise_d.get_noise_2d(p.z + o.z + 500.0, p.x + o.x) * outline_wobble
	if wobble > 0.0:
		var lean := 1.0 + strata * sin((p.y + o.y) * 0.6)
		out.x += _noise_a.get_noise_2d(p.x + o.x, p.z + o.z) * wobble * lean
		out.z += _noise_b.get_noise_2d(p.x + o.x, p.z + o.z) * wobble * lean
	if top_bump > 0.0 and p.y >= size.y * 0.5 - 0.001:
		out.y += _noise_c.get_noise_2d(p.x + o.x, p.z + o.z) * top_bump
	return out

func _steps(a: float, b: float) -> Array[float]:
	var count: int = maxi(1, ceili((b - a) / cell))
	var out: Array[float] = []
	for k in count + 1:
		out.append(a + (b - a) * float(k) / float(count))
	return out

func _build() -> void:
	var h := size * 0.5
	var xs := _steps(-h.x, h.x)
	var ys := _steps(-h.y, h.y)
	var zs := _steps(-h.z, h.z)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if material:
		st.set_material(material)

	var group := 0
	for s in [1.0, -1.0]:
		_grid(st, group, ys, zs, func(u: float, v: float) -> Vector3: return Vector3(s * h.x, u, v), Vector3(s, 0, 0))
		group += 1
		_grid(st, group, ys, xs, func(u: float, v: float) -> Vector3: return Vector3(v, u, s * h.z), Vector3(0, 0, s))
		group += 1
	_grid(st, group, xs, zs, func(u: float, v: float) -> Vector3: return Vector3(u, h.y, v), Vector3.UP)
	group += 1
	if not skip_bottom:
		_grid(st, group, xs, zs, func(u: float, v: float) -> Vector3: return Vector3(u, -h.y, v), Vector3.DOWN)

	st.generate_normals()
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	add_child(mi)
	# El shader del terreno usa la altura de la cima para la capa de nieve y el degradado.
	mi.set_instance_shader_parameter("top_y", global_position.y + h.y)
	_build_icicles()

	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = mesh.create_trimesh_shape()
	add_child(cs)

func _grid(st: SurfaceTool, group: int, us: Array[float], vs: Array[float], fn: Callable, outward: Vector3) -> void:
	st.set_smooth_group(group)
	for i in us.size() - 1:
		for j in vs.size() - 1:
			var a: Vector3 = fn.call(us[i], vs[j])
			var b: Vector3 = fn.call(us[i + 1], vs[j])
			var c: Vector3 = fn.call(us[i + 1], vs[j + 1])
			var d: Vector3 = fn.call(us[i], vs[j + 1])
			# Godot usa sentido horario como cara frontal.
			if (c - a).cross(b - a).dot(outward) < 0.0:
				var t := b
				b = d
				d = t
			for v in [a, b, c, a, c, d]:
				st.add_vertex(_shape(v))

## Carámbanos a lo largo del borde superior (un MultiMesh por formación, sin colisión).
func _build_icicles() -> void:
	var h := size * 0.5
	if not _organic() or icicle_density <= 0.0 or global_position.y + h.y < icicle_min_top_y:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(global_position.round())) + noise_seed
	var xforms: Array[Transform3D] = []
	var r := _corner_r()
	# Recorre las 4 caras: (eje que varía, valor fijo del otro eje).
	for face in 4:
		var along_x := face < 2
		var fixed := (h.z if face == 0 else -h.z) if along_x else (h.x if face == 2 else -h.x)
		var length := (size.x if along_x else size.z) - 2.0 * r
		var count := int(length * icicle_density)
		for k in count:
			var t := rng.randf_range(-length * 0.5, length * 0.5)
			var local := Vector3(t, h.y, fixed) if along_x else Vector3(fixed, h.y, t)
			var top := _shape(local)
			var outward := Vector3(0, 0, signf(fixed)) if along_x else Vector3(signf(fixed), 0, 0)
			var ice_len := rng.randf_range(icicle_length.x, icicle_length.y)
			var width := ice_len * rng.randf_range(0.12, 0.2)
			var b := Basis.from_scale(Vector3(width, ice_len, width))
			var pos := top - outward * 0.12 + Vector3(0, -0.08 - ice_len * 0.5, 0)
			xforms.append(Transform3D(b, pos))
	if xforms.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 1.0
	cone.bottom_radius = 0.0
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_bottom = false
	cone.material = _icicle_material()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Icicles"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

static var _icicle_mat: StandardMaterial3D = null

static func _icicle_material() -> StandardMaterial3D:
	if _icicle_mat == null:
		_icicle_mat = StandardMaterial3D.new()
		_icicle_mat.albedo_color = Color(0.72, 0.88, 1.0)
		_icicle_mat.roughness = 0.08
		_icicle_mat.metallic_specular = 0.9
		_icicle_mat.rim_enabled = true
		_icicle_mat.rim = 0.6
		_icicle_mat.emission_enabled = true
		_icicle_mat.emission = Color(0.35, 0.6, 0.9)
		_icicle_mat.emission_energy_multiplier = 0.3
	return _icicle_mat
