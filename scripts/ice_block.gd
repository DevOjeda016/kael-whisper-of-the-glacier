extends StaticBody3D

## Bloque de hielo que crea Kael. Es un cuerpo estático: se camina encima y
## se trepa por sus paredes (cumple la regla de ángulo). Para usar el modelo
## de Meshy, reemplaza el nodo `Visual` de ice_block.tscn.

@export var appear_time: float = 0.15
@export var shatter_time: float = 0.2
@export var shard_count: int = 14

@onready var visual: Node3D = $Visual

var _breaking: bool = false

func _ready() -> void:
	add_to_group("ice_block")
	visual.scale = Vector3.ONE * 0.2
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, appear_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Rompe el bloque: quita la colisión al instante, suelta fragmentos y se encoge.
func shatter() -> void:
	if _breaking:
		return
	_breaking = true
	Sfx.play_at("ice_shatter", global_position, -3.0)
	remove_from_group("ice_block")
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", true)
	_spawn_shards()
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 0.05, shatter_time)
	tween.tween_callback(queue_free)

func _spawn_shards() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = shard_count
	burst.lifetime = 0.9
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	burst.process_material = mat
	var piece := BoxMesh.new()
	piece.size = Vector3(0.18, 0.18, 0.18)
	var piece_mat := StandardMaterial3D.new()
	piece_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.9)
	piece_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	piece.material = piece_mat
	burst.draw_pass_1 = piece
	parent.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(1.3).timeout.connect(burst.queue_free)
