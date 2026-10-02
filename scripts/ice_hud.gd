extends Control

## HUD del hielo. Siempre visible abajo a la derecha: cuántos bloques quedan
## (rombos llenos = disponibles) y la tecla Q. Con el modo hielo activo se
## añaden la mira central, los controles y el motivo si no se puede crear.

@export var pip_size: float = 11.0
@export var pip_gap: float = 30.0
@export var margin: Vector2 = Vector2(36, 36)

var _tool: Node = null
var _controls: Label = null
var _reason: Label = null
var _key: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls = _make_label(16, Color(0.85, 0.95, 1.0))
	_controls.text = "MODO HIELO   Clic izq: crear   Clic der: romper   Rueda: girar   Q: salir"
	_reason = _make_label(18, Color(1.0, 0.6, 0.55))
	_key = _make_label(15, Color(0.85, 0.95, 1.0, 0.85))

func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _process(_delta: float) -> void:
	if _tool == null:
		var player := get_tree().get_first_node_in_group("player")
		_tool = player.get_node_or_null("IceBlockTool") if player else null
		visible = _tool != null
		return
	var active: bool = _tool.mode_active
	_controls.visible = active
	_reason.visible = active and not _tool.aim_valid
	_reason.text = _tool.invalid_reason
	_key.text = "[Q] salir" if active else "[Q] hielo"

	_controls.reset_size()
	_controls.position = Vector2((size.x - _controls.size.x) * 0.5, size.y - 70.0)
	_reason.reset_size()
	_reason.position = Vector2((size.x - _reason.size.x) * 0.5, size.y * 0.5 + 28.0)
	_key.reset_size()
	var pips_w: float = pip_gap * (_tool.max_blocks - 1)
	_key.position = Vector2(size.x - margin.x - pips_w * 0.5 - _key.size.x * 0.5, size.y - margin.y - 4.0)
	queue_redraw()

func _draw() -> void:
	if _tool == null:
		return
	# Rombos de bloques: llenos = disponibles, huecos = ya en uso.
	var free_count: int = _tool.max_blocks - _tool.blocks.size()
	var y := size.y - margin.y - 22.0
	for i in _tool.max_blocks:
		var c := Vector2(size.x - margin.x - pip_gap * (_tool.max_blocks - 1 - i), y)
		var pts := PackedVector2Array([c + Vector2(0, -pip_size), c + Vector2(pip_size, 0), c + Vector2(0, pip_size), c + Vector2(-pip_size, 0)])
		if i < free_count:
			draw_colored_polygon(pts, Color(0.55, 0.85, 1.0, 0.9))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.9), 1.5, true)
	if not _tool.mode_active:
		return
	var center := size * 0.5
	var col := Color(0.6, 0.9, 1.0, 0.9) if _tool.aim_valid else Color(1.0, 0.4, 0.4, 0.9)
	draw_circle(center, 3.0, col)
	draw_arc(center, 9.0, 0.0, TAU, 24, Color(col, 0.6), 1.5, true)
