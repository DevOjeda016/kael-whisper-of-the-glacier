extends MultiMeshInstance3D

## Témpanos flotando en el mar fuera del área jugable (entre los muros del
## mapa y el anillo de glaciares). Solo decoración: sin colisión, así no
## cambian ningún puzzle. Un MultiMesh = una sola llamada de dibujo.

@export var count: int = 70
@export var inner_radius: float = 165.0
@export var outer_radius: float = 225.0
@export var size_range: Vector2 = Vector2(2.0, 9.0)
@export var sea_level: float = -1.5
@export var floe_seed: int = 21
@export var material: Material

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = floe_seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _floe_mesh()
	mm.instance_count = count
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner_radius * inner_radius, outer_radius * outer_radius))
		var s := rng.randf_range(size_range.x, size_range.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.2), s))
		var pos := Vector3(cos(a) * r, sea_level, sin(a) * r)
		mm.set_instance_transform(i, Transform3D(b, pos))
	multimesh = mm

## Losa irregular: un polígono de 7 lados con radios al azar, 0.5 m sobre el agua.
func _floe_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = floe_seed + 1
	var sides := 7
	var ring: Array[Vector2] = []
	for k in sides:
		var a := TAU * k / sides
		ring.append(Vector2(cos(a), sin(a)) * rng.randf_range(0.7, 1.0))
	var top := 0.5
	var bottom := -0.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if material:
		st.set_material(material)
	for k in sides:
		var p0 := ring[k]
		var p1 := ring[(k + 1) % sides]
		# Cara de arriba (horario visto desde arriba: frontal en Godot).
		st.add_vertex(Vector3(0, top, 0))
		st.add_vertex(Vector3(p0.x, top, p0.y))
		st.add_vertex(Vector3(p1.x, top, p1.y))
		# Lado.
		var a0 := Vector3(p0.x, top, p0.y)
		var a1 := Vector3(p1.x, top, p1.y)
		var b0 := Vector3(p0.x * 0.9, bottom, p0.y * 0.9)
		var b1 := Vector3(p1.x * 0.9, bottom, p1.y * 0.9)
		for v in [a0, b1, a1, a0, b0, b1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
