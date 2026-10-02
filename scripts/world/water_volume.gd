extends Area3D

## Volumen de agua: el nodo está a la altura de la SUPERFICIE y su colisión
## se extiende hacia abajo. Avisa a quien entre (el jugador) para que nade.

func _ready() -> void:
	add_to_group("water_volume")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_surface_y() -> float:
	return global_position.y

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("ice_block"):
		Sfx.play_at("splash", Vector3(body.global_position.x, get_surface_y(), body.global_position.z), -6.0)
	if body.has_method("enter_water"):
		body.enter_water(self)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_water"):
		body.exit_water(self)
