extends Label

## Contador de progreso: puntos de interés resueltos y peces brillantes.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.poi_solved.connect(func(_id: String): _refresh())
	GameState.fish_changed.connect(func(_n: int): _refresh())
	_refresh()

func _refresh() -> void:
	text = "Puntos de interés %d/%d   ·   Peces %d" % [GameState.solved_count(), GameState.total_pois, GameState.fish_count]
