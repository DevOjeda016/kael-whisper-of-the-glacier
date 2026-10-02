extends Area3D

## Tótem de punto de control: al tocarlo, Kael reaparece aquí si cae fuera
## del mapa (sin castigo, coherente con "sin fracaso duro").

@export var respawn_offset: Vector3 = Vector3(0, 0.2, 2.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("set_respawn_point"):
		body.set_respawn_point(global_position + respawn_offset)
		print("Punto de control guardado en ", global_position)
