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
		var inst := scene.instantiate() as Node3D
		add_child(inst)
		inst.global_position = hit.position
		inst.rotation.y = rng.randf() * TAU
		inst.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)
		placed += 1
