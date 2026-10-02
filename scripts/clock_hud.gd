extends Control

## Reloj del ciclo día/noche (abajo a la izquierda): un sol o una luna y la hora.

@export var icon_radius: float = 11.0
@export var margin: Vector2 = Vector2(30, 34)

var _cycle: Node = null
var _label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func _process(_delta: float) -> void:
	if _cycle == null:
		_cycle = get_tree().get_first_node_in_group("day_night")
		visible = _cycle != null
		return
	var h: float = _cycle.get_hour()
	var hh := int(h)
	var mm := int((h - hh) * 60.0) / 10 * 10   # de 10 en 10, como un reloj tranquilo
	_label.text = "%02d:%02d" % [hh, mm]
	_label.reset_size()
	_label.position = Vector2(margin.x + icon_radius * 2.0 + 8.0, size.y - margin.y - _label.size.y * 0.5)
	queue_redraw()

func _draw() -> void:
	if _cycle == null:
		return
	var c := Vector2(margin.x + icon_radius, size.y - margin.y)
	if _cycle.is_night():
		# Luna creciente: un disco claro tapado por otro del color del fondo (recortado con alfa).
		draw_circle(c, icon_radius, Color(0.85, 0.9, 1.0, 0.95))
		draw_circle(c + Vector2(icon_radius * 0.45, -icon_radius * 0.25), icon_radius * 0.85, Color(0.1, 0.14, 0.25, 0.95))
	else:
		var sun_col := Color(1.0, 0.85, 0.45, 0.95)
		draw_circle(c, icon_radius * 0.6, sun_col)
		for i in 8:
			var a := TAU * i / 8.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * icon_radius * 0.8, c + dir * icon_radius * 1.15, sun_col, 2.0, true)
