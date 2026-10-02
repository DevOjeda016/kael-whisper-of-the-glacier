extends Area3D

## Punto de interés (marcador vacío por ahora): avisa la primera vez que
## Kael entra. La lógica de puzzle/historia se agregará sobre esta señal.

signal visited(id: String)

@export var poi_id: String = "poi"

var _visited: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = poi_id

func _on_body_entered(body: Node3D) -> void:
	if _visited or not body.is_in_group("player"):
		return
	_visited = true
	print("POI visitado: ", poi_id)
	visited.emit(poi_id)
