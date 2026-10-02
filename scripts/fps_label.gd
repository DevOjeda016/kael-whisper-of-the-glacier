extends Label

## Contador de FPS de depuración (para medir rendimiento desde el grey-box).

func _process(_delta: float) -> void:
	text = "FPS: %d" % Engine.get_frames_per_second()
