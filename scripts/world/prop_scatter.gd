extends Node3D

## Esparce copias de una escena (roca, cristal...) sobre el terreno que haya
## debajo, apoyándolas con un raycast. Para usar un modelo de Meshy basta con
## asignar otra escena en `scene` (o editar la escena provisional).

@export var scene: PackedScene
@export var count: int = 20
@export var area: Vector2 = Vector2(100, 100)   # tamaño (x, z) centrado en este nodo
@export var ray_top: float = 100.0
@export var ray_depth: float = 150.0
@export var min_scale: float = 0.8
@export var max_scale: float = 1.4
@export var min_normal_y: float = 0.9           # solo superficies casi planas
@export var scatter_seed: int = 1
@export var footprint: float = 1.0              # radio del prop a escala 1: debe haber suelo bajo todo él (no queda colgando de un borde)

func _ready() -> void:
	# Las colisiones recién creadas entran al motor de física un frame después.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_scatter()

func _scatter() -> void:
	if scene == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var space := get_world_3d().direct_space_state
	var placed := 0
	for i in count * 6:
		if placed >= count:
			break
		var x := global_position.x + rng.randf_range(-area.x, area.x) * 0.5
		var z := global_position.z + rng.randf_range(-area.y, area.y) * 0.5
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(x, global_position.y + ray_top, z),
			Vector3(x, global_position.y + ray_top - ray_depth, z))
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < min_normal_y:
			continue
		var s := rng.randf_range(min_scale, max_scale)
		if not _fully_supported(space, hit.position, footprint * s):
			continue
		var inst := scene.instantiate() as Node3D
		add_child(inst)
		inst.global_position = hit.position
		inst.rotation.y = rng.randf() * TAU
		inst.scale = Vector3.ONE * s
		placed += 1

## ¿Hay suelo a la misma altura alrededor de `pos`? Evita props flotando en filos.
func _fully_supported(space: PhysicsDirectSpaceState3D, pos: Vector3, radius: float) -> bool:
	for k in 6:
		var a := TAU * float(k) / 6.0
		var p := pos + Vector3(cos(a), 0.0, sin(a)) * radius
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 0.6)
		if space.intersect_ray(q).is_empty():
			return false
	return true
