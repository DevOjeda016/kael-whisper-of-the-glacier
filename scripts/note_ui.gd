extends Control

## Notas ambientales: un panel centrado que aparece, dura unos segundos y se
## desvanece. Se busca por el grupo "note_ui".

@export var show_time: float = 5.0

var _panel: PanelContainer = null
var _label: Label = null

func _ready() -> void:
	add_to_group("note_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	_panel.position.y = 90.0

func show_note(text: String, fish: int = 0) -> void:
	var body := "“%s”" % text if text != "" else ""
	if fish > 0:
		body += ("\n\n" if body != "" else "") + "+%d pez brillante" % fish
	_label.text = body
	_panel.reset_size()
	_panel.position.x = (size.x - _panel.size.x) * 0.5
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tween.tween_interval(show_time)
	tween.tween_property(_panel, "modulate:a", 0.0, 1.0)
