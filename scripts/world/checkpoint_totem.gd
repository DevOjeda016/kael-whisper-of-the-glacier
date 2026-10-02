extends Area3D

## Tótem de punto de control: al tocarlo, Kael reaparece aquí si cae fuera
## del mapa (sin castigo, coherente con "sin fracaso duro").
## Además, como las fogatas de BotW, se puede descansar en él (E) para pasar
## el tiempo: de día hasta la noche, de noche hasta la mañana.

@export var respawn_offset: Vector3 = Vector3(0, 0.2, 2.0)
@export var morning_hour: float = 6.0
@export var night_hour: float = 21.0

var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if body.has_method("set_respawn_point"):
		body.set_respawn_point(global_position + respawn_offset)
		print("Punto de control guardado en ", global_position)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	var ui := get_tree().get_first_node_in_group("hint_ui")
	if ui:
		ui.hide_hint(self)

func _process(_delta: float) -> void:
	if not _player_inside:
		return
	var cycle := get_tree().get_first_node_in_group("day_night")
	var ui := get_tree().get_first_node_in_group("hint_ui")
	if cycle == null or ui == null:
		return
	if cycle.is_resting():
		ui.hide_hint(self)
	else:
		ui.show_hint("[E] Descansar hasta %s" % ("la mañana" if cycle.is_night() else "la noche"), self)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		rest()

## Descansa hasta la mañana (si es de noche) o hasta la noche (si es de día).
func rest() -> void:
	var cycle := get_tree().get_first_node_in_group("day_night")
	if cycle == null or cycle.is_resting():
		return
	cycle.rest_until(morning_hour if cycle.is_night() else night_hour)
