extends Control

## Pistas de tutorial: un texto abajo al centro mientras Kael está dentro de
## una `HintZone`. Se busca por el grupo "hint_ui".

var _label: Label = null
var _owner: Node = null
var _tween: Tween = null

func _ready() -> void:
	add_to_group("hint_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("outline_size", 5)
	_label.modulate.a = 0.0
	add_child(_label)

func show_hint(text: String, from: Node) -> void:
	if from == _owner and text == _label.text and _label.modulate.a > 0.0:
		return   # ya se está mostrando (algunas zonas la piden cada frame)
	_owner = from
	_label.text = text
	_label.reset_size()
	_label.position = Vector2((size.x - _label.size.x) * 0.5, size.y - 150.0)
	_fade(1.0)

## Solo la zona que mostró la pista puede esconderla (las zonas se pueden pisar).
func hide_hint(from: Node) -> void:
	if from == _owner:
		_owner = null
		_fade(0.0)

func _fade(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", target, 0.4)
