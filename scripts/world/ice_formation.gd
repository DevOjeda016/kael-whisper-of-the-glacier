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

var _noise_a := FastNoiseLite.new()
var _noise_b := FastNoiseLite.new()
var _noise_c := FastNoiseLite.new()

func _ready() -> void:
	for n in [_noise_a, _noise_b, _noise_c]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_a.seed = noise_seed
	_noise_a.frequency = 0.045
	_noise_b.seed = noise_seed + 101
	_noise_b.frequency = 0.045
	_noise_c.seed = noise_seed + 202
	_noise_c.frequency = 0.07
	_build()

func _shape(p: Vector3) -> Vector3:
	var out := p
	var o := global_position
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
