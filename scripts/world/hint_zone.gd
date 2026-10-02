extends Area3D

## Zona de pista: mientras Kael está dentro se muestra `text` abajo en pantalla.
## Si `hide_when_solved` tiene un poi_id, la pista deja de salir al resolverlo.

@export_multiline var text: String = ""
@export var size: Vector3 = Vector3(10, 4, 10)
@export var hide_when_solved: String = ""

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if hide_when_solved != "" and GameState.is_solved(hide_when_solved):
		return
	var ui := get_tree().get_first_node_in_group("hint_ui")
	if ui:
		ui.show_hint(text, self)

func _on_exit(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var ui := get_tree().get_first_node_in_group("hint_ui")
	if ui:
		ui.hide_hint(self)
