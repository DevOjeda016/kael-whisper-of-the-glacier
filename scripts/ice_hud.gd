extends Control

## Mira central y texto de ayuda del modo hielo; solo se ven con el modo activo.

var _tool: Node = null
var _label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	_label.position.y -= 40.0
	add_child(_label)
	visible = false

func _process(_delta: float) -> void:
	if _tool == null:
		var player := get_tree().get_first_node_in_group("player")
		_tool = player.get_node_or_null("IceBlockTool") if player else null
		return
	visible = _tool.mode_active
	if visible:
		_label.text = "MODO HIELO  |  Clic izq: crear  |  Clic der: romper  |  Rueda: girar  |  Q: salir\nBloques: %d/%d" % [_tool.blocks.size(), _tool.max_blocks]
		_label.position.x = (size.x - _label.size.x) * 0.5
		queue_redraw()

func _draw() -> void:
	if _tool == null:
		return
	var c := size * 0.5
	var col := Color(0.6, 0.9, 1.0, 0.9) if _tool.aim_valid else Color(1.0, 0.4, 0.4, 0.9)
	draw_circle(c, 3.0, col)
	draw_arc(c, 9.0, 0.0, TAU, 24, Color(col, 0.6), 1.5, true)
