extends ColorRect

## Fundido de pantalla (p. ej. al ahogarse). Se busca por el grupo "screen_fade".

func _ready() -> void:
	add_to_group("screen_fade")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "color:a", alpha, time)
